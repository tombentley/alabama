import ceylon.collection {
    HashMap
}
import ceylon.language.meta.declaration {
    Package,
    ClassOrInterfaceDeclaration
}
import ceylon.language.meta.model {
    Type
}

import com.github.tombentley.typeparser {
    TypeParser,
    TypeFormatter
}

"""A contract for converting between types and "type names" in an 
   invertible way.
   """
shared interface TypeNaming {
    throws(`class Exception`, "The given name cannot be parsed as a type")
    shared formal Type<> type(String name);
    shared formal String name(Type<> type);
}

// Avoid a shared import of the type parser by not depending on its
// Imports alias, so redeclare it locally
shared alias Imports=>List<Package|ClassOrInterfaceDeclaration|<String->ClassOrInterfaceDeclaration>>;

"""Type naming using fully-qualified or unqualified type expressions"""
shared class TypeExpressionTypeNaming(
    Imports imports=[], 
    Boolean abbreviate = false) satisfies TypeNaming {
    
    TypeParser parser = TypeParser {
        imports = imports;
        optionalAbbreviation=abbreviate;
        emptyAbbreviation=abbreviate;
        entryAbbreviation=abbreviate;
        sequenceAbbreviation=abbreviate;
        
        iterableAbbreviation=abbreviate;
        
        tupleAbbreviation=abbreviate;
        callableAbbreviation=abbreviate;
    };
    
    TypeFormatter formatter = TypeFormatter {
        imports=imports;
        optionalAbbreviation=abbreviate;
        emptyAbbreviation=abbreviate;
        entryAbbreviation=abbreviate;
        sequenceAbbreviation=abbreviate;
        
        iterableAbbreviation=abbreviate;
        
        tupleAbbreviation=abbreviate;
        callableAbbreviation=abbreviate;
    };
    
    shared actual Type<> type(String name) {
        value r = parser.parse(name);
        if (is Type<> r) {
            return r;
        } else {
            throw r;
        }
    }
    shared actual String name(Type<Anything> type) {
        return if (imports.empty && !abbreviate) then type.string else formatter.format(type);
    }
}


"""A simple bijective mapping between types and strings"""
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

