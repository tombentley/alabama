import ceylon.language.meta.model {
    Type
}
import ceylon.collection {
    HashMap
}
"""A contract for obtaining a [[Type]] from the value of a 
   "@type" property in the JSON data being deserialized.
   """
shared interface TypeNaming {
    shared formal Type<> type(String name);
    shared formal String name(Type<> type);
}
shared object fqTypeNaming satisfies TypeNaming {
    shared actual Type<> type(String name) => parseType(name);
    shared actual String name(Type<Anything> type) => type.string;
}
shared class LogicalTypeNaming({<String->Type<>>*} names) satisfies TypeNaming {
    value toType = HashMap<String,Type<>>{*names};
    value toName = HashMap<Type<>, String>{};
    for (name -> type in names) {
        toName.put(type, name);
    }
    shared actual Type<> type(String name) => toType[name] else nothing;
    shared actual String name(Type<Anything> type) => toName[name] else nothing;
}

