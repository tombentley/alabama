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

class Stack(parent) {
    shared Stack? parent;
    //shared Object instance;
    shared variable Integer num = 0;
}

shared abstract class Serializer() satisfies Member{
    
    variable Stack? stack = null;
    
    shared formal void print(String s);
    
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
    
    void nul() {
        print("null");
    }
    
    void int(Integer|Float instance) {
        print(instance.string);
    }
    
    void str(String instance) {
        // TODO quoting
        print("\"");
        print(instance);
        print("\"");
    }
    
    void bool(Boolean instance) {
        print(instance.string);
    }
    
    void arr(Type modelType, {Anything*} instance) {
        value it = iteratedType(modelType);
        print("[");
        variable Boolean comma = false;
        for (Anything r in instance) {
            if (comma) {
                print(",");
            }
            val(it, r);
            comma = true;
        }
        print("]");
    }
    
    void obj(Type modelType, Object instance) {
        this.stack = Stack(this.stack);
        print("{");
        assert(is Class<Object> c = type(instance));
        // TODO chose between the two depending on annotations, constructors etc.
        memberizer(c).serializeMembers(c, instance, this);
        print("}");
        assert(exists s = this.stack);
        this.stack = s.parent;
    }
    
    shared actual void member(String name, Type modelType, Anything instance) {
        if (exists s=stack) {
            if (s.num > 0) {
                print(",");
            }
            s.num++;
        }
        str(name);
        print(":");
        val(modelType, instance);
    }
    
    void val(Type modelType, Anything instance) {
        if (!exists instance) {
            nul();
        } else if (is Integer|Float instance) {
            int(instance);
        } else if (is String instance) {
            str(instance);
        } else if (is Boolean instance) {
            bool(instance);
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

shared class StringSerializer() extends Serializer() {
    StringBuilder sb = StringBuilder();
    
    shared actual void print(String s) {
        sb.append(s);
    }
    
    shared actual String string => sb.string;
}

shared String serialize(Anything instance) {
    StringSerializer ss = StringSerializer();
    ss.serialize(instance);
    return ss.string;
}
shared void runser() {
    print(serialize(example));
    print(serialize(exampleNull));
    print(serialize(exampleLate));
}