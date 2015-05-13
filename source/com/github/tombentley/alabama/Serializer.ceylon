import ceylon.language.meta {
    type
}
import ceylon.language.meta.model {
    Class,
    Type,
    Attribute,
    Constructor
}
import ceylon.language.meta.declaration {
    ValueDeclaration,
    ConstructorDeclaration,
    ClassDeclaration
}
import ceylon.collection {
    HashMap
}
import ceylon.json {
    Visitor,
    StringEmitter
}

"Figures out what the members of the JSON hash should be, and calls back on 
 the serializer with those members.
 
 In effect implementors encapsulate a construction strategy for the instance"
shared interface Memberizer {
    shared formal void serializeMembers(ClassSerialization cs, Class<Object> c, 
        Object instance, Member serializer);
}

"Treats all constructor parameters of [[serializeMembers.c]] as members of 
 the JSON hash, thus permitting construction via (named argument) instantiation"
see(`class NamedInvocation`)
shared object namedParameterMemberizer satisfies Memberizer {
        
    shared actual void serializeMembers(ClassSerialization cs, Class<Object> c, 
            Object instance, Member serializer) {
        value pds = cs.constructor.parameterDeclarations;
        Type<Anything>[] pts;
        if (cs.constructor is ConstructorDeclaration) {
            assert(exists ctor = c.getConstructor(cs.constructor.name));
            pts = ctor.parameterTypes;
        } else {
            pts = c.parameterTypes;
        }
        variable value index = 0;
        for (pd in pds) {
            assert(exists pt=pts[index]);
            if (is ValueDeclaration pd) {
                serializer.member(pd.name, pt, pd.memberGet(instance));
            }
            index++;
        }
    }
}

"Treats all `variable` or `late` attributes of the instance as members, thus 
 requiring a nullary class initializer or constructor for deserialization."
see(`class NullaryInvocationAndInjection`)
shared object variableOrLateMemberizer satisfies Memberizer {
    shared actual void serializeMembers(ClassSerialization cs, Class<Object> c, 
        Object instance, Member serializer) {
        value cd = cs.clazz;
        for (ad in cd.memberDeclarations<ValueDeclaration>()) {
            if (ad.variable 
                || ad.late) {
                //value type = ad.memberApply<Object, Anything>(c).type;
                value x = `function ValueDeclaration.memberApply`.memberInvoke(ad, [c], c);
                assert(exists x);
                value y = `value Attribute.type`.memberGet(x);
                assert(is Type y);
                serializer.member(ad.name, y, ad.memberGet(instance));
            }
        }
    }
}

shared interface Member {
    shared formal void member(String name, Type modelType, Anything instance);
}


interface TypeHinter {
    shared formal void hint(Type type, Visitor visitor);
}

class WrapperObjectTypeHinter(PropertyTypeHint property) satisfies TypeHinter {
    shared actual void hint(Type<Anything> type, Visitor visitor) {
        visitor.onStartObject();
        visitor.onKey(property.property);
        visitor.onString(property.naming.name(type));
        visitor.onKey("value");
        // TODO delegate to ??? to continue tree walk
        visitor.onEndObject();
    }
}
class WrapperArrayTypeHinter(TypeNaming typeNaming) satisfies TypeHinter {
    shared actual void hint(Type<Anything> type, Visitor visitor) {
        visitor.onStartObject();
        visitor.onString(typeNaming.name(type));
        // TODO delegate to ??? to continue tree walk
        visitor.onEndObject();
    }
}
class PropertyTypeHinter(PropertyTypeHint property) satisfies TypeHinter {
    shared actual void hint(Type type, Visitor visitor) {
        visitor.onKey(property.property);
        visitor.onString(property.naming.name(type));
    }
}

"""A Serializer converts a tree of Ceylon objects to JSON. 
   It's not much more than a way to introspect an recurse through an object tree, really."""
see(`function serialize`)
shared class Serializer() satisfies Member{
    
    late variable Visitor visitor;
    
    ConstructorDeclaration? hasNullaryConstructor(Class<Object> c) {
        for (ctor in c.declaration.constructorDeclarations()) {
            if (ctor.parameterDeclarations.empty) {
                return ctor;
            }
        }
        return null;
    }
    
    HashMap<ClassDeclaration, ClassSerialization> metadata = HashMap<ClassDeclaration, ClassSerialization>();
    
    ClassSerialization model(Class<Object> clazz) {
        ClassSerialization cs;
        if (exists r = metadata[clazz.declaration]) {
            cs = r;
        } else {
            Memberizer memberizer;
            if (clazz is Class<Object, []>
                || hasNullaryConstructor(clazz) exists) {
                // TODO chose between the two depending on annotations, constructors etc.
                memberizer = variableOrLateMemberizer;
            } else {
                memberizer = namedParameterMemberizer;
            }
            cs = readClass(clazz.declaration, memberizer);
            
            metadata.put(clazz.declaration, cs);
        }
        return cs;
    }
    
    Type? typeInfo() {
        // TODO
        // if the actual type is different from the model type
        return null;
    }
    
    void arr(Type modelType, {Anything*} instance) {
        value it = iteratedType(modelType);
        visitor.onStartArray();
        for (Anything r in instance) {
            val(it, r);
        }
        visitor.onEndArray();
    }
    
    void obj(Type modelType, Object instance) {
        visitor.onStartObject();
        assert(is Class<Object> c = type(instance));
        value m = model(c);
        m.memberizer.serializeMembers(m, c, instance, this);
        visitor.onEndObject();
    }
    
    shared actual void member(String name, Type modelType, Anything instance) {
        visitor.onKey(name);
        val(modelType, instance);
    }
    
    void val(Type modelType, Anything instance) {
        if (!exists instance) {
            visitor.onNull();
        } else if (is Integer|Float instance) {
            visitor.onNumber(instance);
        } else if (is String instance) {
            visitor.onString(instance);
        } else if (is Boolean instance) {
            visitor.onBoolean(instance);
        } else if (is {Anything*} instance) {
            arr(modelType, instance);
        } else {
            obj(modelType, instance);
        }
    }
    
    "Serialize the given [[instance]] as events on the given [[visitor]]."
    shared void serialize(Visitor visitor, Anything instance, Type modelType=type(instance)) {
        this.visitor = visitor;
        val(modelType, instance);
    }
}

"A utility for serializing an instance to a JSON-formatted String."
shared String serialize(Anything instance, Boolean pretty = false) {
    value em = StringEmitter(pretty);
    Serializer ss = Serializer();
    ss.serialize(em, instance);
    return em.string;
}
