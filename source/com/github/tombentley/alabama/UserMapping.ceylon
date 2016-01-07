
"Constract to serialize certain user specified classes to a JSON string.
 
 This is useful for classes such as `Uri`, `Datetime` etc which can be 
 formatted as strings and parsed from strings."
shared interface StringSerializer {
    "The `String` representation of the given `instance`, or null 
     if this serializer cannot serialize the given instance."
    shared formal String? serialize(Object instance);
    
    "Parse the given string representation and return it, or null if the 
     string could not be parsed"
    shared formal Object|Null deserialize(String string);
}

