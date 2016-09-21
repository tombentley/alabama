import ceylon.language.meta.model {
    Type
}
"""A contract for a bijective conversion between instances of 
   some `Instance` and a `String` representation of such instances.
   """
shared interface StringSerializer<Instance> {
    "Parse the given string representation as an `Instance`."
    throws(`class Exception`, "The given `serialForm` cannot be parsed as a `Instance`.")
    shared formal Instance deserialise(String serialForm);
    
    "Format the given instance as a string.
     
     The output of this method should be acceptable to [[deserialize()|deserialise]] 
     without it throwing an exception."
    shared formal String serialise(Instance instance);
}

shared alias TypeNaming => StringSerializer<Type<>>;