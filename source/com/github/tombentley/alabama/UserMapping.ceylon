import ceylon.language.meta {
    typeLiteral
}
import ceylon.language.meta.declaration {
    FunctionDeclaration,
    ClassOrInterfaceDeclaration
}
import ceylon.language.meta.model {
    Type
}


"Contract to serialize certain user specified classes to a JSON string.
 
 This is useful for classes such as `Uri`, `Datetime` etc which can be 
 formatted as strings.
 
 For use cases which require round trip serialization, it is usual to 
 satisfy both this and [[StringDeserializer]] in the same class, 
 to help ensure a fully reversible mapping."
see (`interface StringDeserializer`)
shared interface StringSerializer<in Element> 
        given Element satisfies Object {
    "The `String` representation of the given `instance`"
    shared formal String serialize(Element instance);
    
    "The type of instance that this serializer handles."
    // This is necessary because when serializing we need to use this type
    // rather than type(instance) as the "class" type, but
    // the metamodel doesn't support getting the principle
    // instantiation of a supertype 
    shared Type<> type => typeLiteral<Element>();
}

"Contract to deserialize certain user specified classes from a JSON string.
 
 This is useful for classes such as `Uri`, `Datetime` etc which can be 
 parsed from strings.
 
 For use cases which require round trip serialization, it is usual to 
 satisfy both this and [[StringSerializer]] in the same class, 
 to help ensure a fully reversible mapping."
see (`interface StringSerializer`)
shared interface StringDeserializer<out Element> 
        given Element satisfies Object {
    "Parse the given string representation and return it, or null if the 
     string could not be parsed"
    shared formal Element deserialize(String string);
}

"Contract to serialize certain user specified classes to a JSON array.
 
 This is useful for classes such as `ArrayList`, `LinkedList` etc which 
 can be formatted as arrays.
 
 For use cases which require round trip serialization, it is usual to 
 satisfy both this and [[ArrayDeserializer]] in the same class, 
 to help ensure a fully reversible mapping."
shared interface ArraySerializer<in Container> 
        given Container<Element> {
    "The elements constituting JSON array elements of the given instance"
    shared formal {Element*}? enumerate<Element>(Container<Element> instance);
}


"Contract to deserialize certain user specified classes from a JSON array.
 
 This is useful for classes such as `ArrayList`, `LinkedList` etc which 
 can be parsed from arrays.
 
 For use cases which require round trip serialization, it is usual to 
 satisfy both this and [[ArraySerializer]] in the same class, 
 to help ensure a fully reversible mapping."
shared interface ArrayDeserializer<out Container> 
        given Container<Element> {
    shared formal Container<Element> deserialize<Element>(List<Element> elements);
}

shared class ListSerializer(FunctionDeclaration f) 
        satisfies ArraySerializer<List>&ArrayDeserializer<List> {
    
    shared actual {Element*}? enumerate<Element>(List<Element> instance) {
        return instance;
    }
    
    shared actual List<Element> deserialize<Element>(List<Element> elements) {
        return nothing;//f.invoke([typeLiteral<Element>()], elements);
    }
}

