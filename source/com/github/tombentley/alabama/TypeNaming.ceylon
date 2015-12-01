import ceylon.language.meta.model {
    Type
}
import ceylon.collection {
    HashMap
}
import com.github.tombentley.typeparser {
    parseType
}
"""A contract for converting between types and "type names" in an 
   invertible way.
   """
shared interface TypeNaming {
    throws(`class Exception`, "The given name cannot be parsed as a type")
    shared formal Type<> type(String name);
    shared formal String name(Type<> type);
}

"""Encoding and decoding of instance types using a ("@type") 
   attribute in the JSON hash whose value is the fully 
   qualified type name."""
shared object fqTypeNaming satisfies TypeNaming {
    shared actual Type<> type(String name) {
        value r = parseType(name);
        if (is Type<> r) {
            return r;
        } else {
            throw r;
        }
    }
    shared actual String name(Type<Anything> type) => type.string;
}

"""Encoding and decodeing of instance types using a ("@type") 
   attribute in the JSON hash whose value is an arbitrary `String` in a 
   bijective mapping from types to type names."""
shared class LogicalTypeNaming({<String->Type<>>*} names) satisfies TypeNaming {
    value toType = HashMap<String,Type<>>{*names};
    value toName = HashMap<Type<>, String>{};
    for (name -> type in names) {
        toName.put(type, name);
    }
    shared actual Type<> type(String name) {
        if (exists r=toType[name]) {
            return r;
        }
        throw Exception("No type mapping for name ``name``");
    }
    shared actual String name(Type<Anything> type) {
        if (exists r = toName[name]) {
            return r;
        }
        throw Exception("No type mapping for type ``type``");
    }
}

