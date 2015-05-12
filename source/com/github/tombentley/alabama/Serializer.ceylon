import ceylon.language.meta {
    type
}
import ceylon.language.meta.model {
    Class,
    Type,
    Attribute
}
import ceylon.language.meta.declaration {
    ValueDeclaration,
    ConstructorDeclaration
}
import ceylon.collection {
    HashMap
}
import ceylon.json {
    Visitor,
    StringEmitter
}

shared interface Memberizer {
    shared formal void serializeMembers(Class<Object> c, Object instance, Member serializer);
}

shared object namedParameterMemberizer satisfies Memberizer {
        
    shared actual void serializeMembers(Class<Object> c, Object instance, Member serializer) {
        value pds = c.declaration.parameterDeclarations;
        value pts = c.parameterTypes;
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

shared object variableOrLateMemberizer satisfies Memberizer {
    shared actual void serializeMembers(Class<Object> c, Object instance, Member serializer) {
        value cd = c.declaration;
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

shared class Serializer(Visitor visitor) satisfies Member{
    
    ConstructorDeclaration? hasNullaryConstructor(Class<Object> c) {
        for (ctor in c.declaration.constructorDeclarations()) {
            if (ctor.parameterDeclarations.empty) {
                return ctor;
            }
        }
        return null;
    }
    
    HashMap<Class<Object>, Memberizer> mc = HashMap<Class<Object>, Memberizer>();
    
    Memberizer memberizer(Class<Object> c) {
        Memberizer result;
        if (exists r = mc[c]) {
            result = r;
        } else { 
            if (c is Class<Object, []>
                || hasNullaryConstructor(c) exists) {
                result = variableOrLateMemberizer;
            } else {
                result = namedParameterMemberizer;
            }
            mc.put(c, result);
        }
        return result;
    }
    
    
    void arr(Type modelType, {Anything*} instance) {
        value it = iteratedType(modelType);
        visitor.onStartArray();
        variable Boolean comma = false;
        for (Anything r in instance) {
            if (comma) {
                //print(",");
            }
            val(it, r);
            comma = true;
        }
        visitor.onEndArray();
    }
    
    void obj(Type modelType, Object instance) {
        visitor.onStartObject();
        assert(is Class<Object> c = type(instance));
        // TODO chose between the two depending on annotations, constructors etc.
        memberizer(c).serializeMembers(c, instance, this);
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
    
    shared void serialize(Anything instance, Type modelType=type(instance)) {
        val(modelType, instance);
    }
}


shared String serialize(Anything instance) {
    value em = StringEmitter();
    Serializer ss = Serializer(em);
    ss.serialize(instance);
    return em.string;
}
shared void runser() {
    print(serialize(example));
    print(serialize(exampleNull));
    print(serialize(exampleLate));
}