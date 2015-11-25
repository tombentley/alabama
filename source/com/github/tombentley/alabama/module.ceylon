"""A JSON-based serialization library. This module can be used to 
   serialize and deserialize object Ceylon graphs to/from JSON.
   
   Efforts are made to make the JSON reasonably idiomatic, 
   while still supporting things like cyclic Ceylon 
   instance graphs.
   
   The API offered by this module is to serialize/deserialize a 
   single instance, called the root instance. In practice this is 
   not really a limitation because you can always serialize a single 
   sequence of several other instances. 
   
   # Serialized form
   
   ## 'Simple' classes
   
   An instance of a simple class will serialize to a JSON object, so given
   
       class Person(first, last) {
           shared String first;
           shared String last;
       }
       
   then the root instance `Person("John", "Doe")` will serialize to: 
       
   ```javascript
   {
     "first":"John",
     "last":"Doe"
   }
   ```
   
   There are some built in special cases:
   
   * Ceylon `String` and `Character` instances map to/from JSON strings,
   * Ceylon `Integer` and `Float` instances map to/from JSON numbers,
   * Ceylon `Boolean` instances map to/from JSON true or false,
   * Ceylon's `Null` instance maps to/from JSON's null,
   * Ceylon `Array` and `Sequential`s map to/from the JSON array
     notation (with type information added if this would 
     result in ambiguity during deserialization).
   
   ## Including type information
   
   Consider deserializing the above example JSON again:
   
   ```javascript
   {
     "first":"John",
     "last":"Doe"
   }
   ```
   
   Note that it does not include information about the Ceylon class
   which was serialized to produce this JSON. So unless the 
   deserializing client knows *a priori* that it is only deserializing 
   `Person` instances it cannot possibly deserialize it. Thus to be 
   deserializable by *unspecialized Ceylon clients* 
   additional type information 
   needs to be included.
   
   Of course if the serialized JSON is never consumed by
   *unspecialized Ceylon clients* such type information is not needed). 
   
   Examples of when such additional type 
   information is needed include:
   
   * Where the root instance's type is not statically known at the 
     point of deserialization
     (for example if the receiver knows it will only be deserializing 
     `Person` instances it is not necessary to include type information,
     but if they can deserialize `Person|Organsiation` then the message
     needs to discriminate which). 
   * Where a non-root instance is referred to via an attribute with a 
     wider type then the instance type. For example
     
          class Consignment(shipTo) {
              shared Person|Company shipTo;
              // ...
          }
   
   Whatever the cause, [[by default|fqTypeNaming]] the type 
   information is included as an additional JSON "class" property:
   
   ```javascript
   {
     "class":"example:Person",
     "first":"John",
     "last":"Doe"
   }
   ```
   
   The "class" key's value is, generally, a Ceylon type expression 
   (including type arguments for generic types).
   
   Alternatively if the serializing client and deserializing client can agree 
   beforehand a bijective type->name mapping then arbitrary names can be 
   used, see [[LogicalTypeNaming]].
   
   ## Identity
   
   Ceylon instances and the instances they refer to form a directed graph. 
   On the other hand JSON provides a tree-like syntax. So we have to 
   handle the possibility of an instance being referred-to multiple 
   times. Moreover there is also the possibility of cyclic instance graphs, 
   where an instance refers (possibly indirectly) to itself.
   
   To best handle arbitrary object graphs this module assigns ids to 
   instances which occur more than once in the object graph. During 
   serialization the first occurence of the instance is serialized as normal, 
   but with an extra id key, and subsequent occurences refer to that id.
   
   For example given the class:
    
       class Twice(Person inst) {
           shared Person first=inst;
           shared Person second=inst;
       }
        
   and the instance `Twice(john, john)` (where `john` is the `Person` above)
   then the JSON output would look like this:
    
   ```javascript
   {
     "first": { "#":1, first":"John", "second":"Doe" },
     "@second: 1
   }
   ```
    
   The `Person` has an extra `#` JSON key and subsequent references to that 
   instance use property names prefixed with `@` and with that id value.
   
    
   """
module com.github.tombentley.alabama "1.0.0" {
    shared import ceylon.json "1.2.1";
    import ceylon.collection "1.2.1";
}
