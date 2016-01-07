import ceylon.collection {
    ArrayList
}

shared interface UserSerializer of StringSerializer | ArraySerializer {}

"Contract to serialize certain user specified classes to a JSON string.
 
 This is useful for classes such as `Uri`, `Datetime` etc which can be 
 formatted as strings and parsed from strings."
shared interface StringSerializer satisfies UserSerializer {
    "The `String` representation of the given `instance`, or null 
     if this serializer cannot serialize the given instance."
    shared formal String? serialize(Object instance);
    
    "Parse the given string representation and return it, or null if the 
     string could not be parsed"
    shared formal Object|Null deserialize(String string);
}

shared interface ArraySerializer satisfies UserSerializer {
    "The elements constituting JSON array elements of the given instance"
    shared formal {Anything*}? serialize(Object instance);
    
    shared formal Object deserialize<Element>(List<Element> elements);
}

shared class ListSerializer() satisfies ArraySerializer {
    
    shared actual {Anything*}? serialize(Object instance) {
        if (is List<Anything> instance) {
            return instance;
        } else {
            return null;
        }
    }
    shared actual Object deserialize<Element>(List<Element> elements) {
        return ArrayList<Element>{
            elements=elements;
        };
    }
}
