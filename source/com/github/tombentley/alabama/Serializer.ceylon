import ceylon.collection {
    HashMap,
    IdentityMap
}
import ceylon.json {
    Visitor,
    StringEmitter
}
import ceylon.language.meta {
    type,
    typeLiteral
}
import ceylon.language.meta.model {
    Type,
    ClassModel
}
import ceylon.language.serialization {
    SerializationContext,
    Member,
    Outer,
    Element,
    serialization,
    uninitializedLateValue
}

/*
 I need an explicit type when:
 -- the concrete type is not String, Boolean, Float|Integer or Null
 -- concrete type is different from the model type (i.e. when, during deser, 
    it couldn't be infered from the model) 
 */

"A utility for serializing an instance to a JSON-formatted String."
shared String serialize<Instance>(Instance instance, Boolean pretty = false) {
    value em = StringEmitter(pretty);
    Serializer ss = Serializer();
    ss.serialize<Instance>(em, instance);
    return em.string;
}

"Generates ids"
class IdGenerator() {
    variable value id = 1;
    shared Integer next() {
        value result = id;
        "id overflow"
        assert(result > 0);
        id++;
        return result; 
    }
}

// TODO abstract ids, so they're not always Integers. In particular, 
// the id for a particular class might be more like a primary key
// { name="", ... } // id for Person class is name, so no need for "#" key
// with a reference like { "@person": {name=""}, ... }

"A map from instances to items which copes with the distinction between 
 [[Identifiable]] and non-[[Identifiable]] objects."
class InstanceMap<Item>() 
        given Item satisfies Object {
    value identity = IdentityMap<Identifiable, Item>();
    value equality = HashMap<Object, Item>();
    shared Boolean defines(Object key) {
        if (is Identifiable key) {
            return identity.defines(key);
        } else {
            return equality.defines(key);
        }
    }
    shared Item? get(Object key)  {
        if (is Identifiable key) {
            return identity[key];
        } else {
            return equality[key];
        } 
    }
    shared void put(Object key, Item promise)  {
        if (is Identifiable key) {
            identity.put(key, promise);
        } else {
            equality.put(key, promise);
        } 
    }
    shared InstanceMap<Item> filteredByItem(Boolean f(Item it)) {
        value copy = InstanceMap<Item>();
        for (entry in identity) {
            if (f(entry.item)) {
                copy.put(entry.key, entry.item);
            }
        }
        for (entry in equality) {
            if (f(entry.item)) {
                copy.put(entry.key, entry.item);
            }
        }
        return copy;
    }
    
    shared actual String string {
        value sb = StringBuilder();
        for (x->y in identity) {
            sb.append("``y``<-``type(x)``@``identityHash(x)``");
            sb.append(operatingSystem.newline);
        }
        for (x->y in equality) {
            sb.append("``y``<-``type(x)``@``x.hash``");
            sb.append(operatingSystem.newline);
        }
        return sb.string;
    }
}

"""A Serializer converts a tree of Ceylon objects to JSON. 
   It's not much more than a way to introspect an recurse through an object tree, really."""
see(`function serialize`)
shared class Serializer(
    Config config = Config()) {
    
    SerializationContext sc = serialization();
    
    "Find everything reachable from root, 
     giving things reachable via multiple paths an id.
     
     When we actually emit JSON output, the first time an instance in the returned map 
     is encountered it is emitted with the corresponding id, and the id's 
     sign is flipped. Subsequent occurrences (i.e. negative ids) will refer to that id."
    InstanceMap<Integer> assignedIds(Anything root) {
        InstanceMap<Integer> counts = InstanceMap<Integer>();
        if (exists root) {
            assignedIdsInternal(IdGenerator(), root, counts);
        }
        value x = counts.filteredByItem(function (Integer item) => item >= 0);
        return x;
    }
    
    void assignedIdsInternal(IdGenerator idGenerator, Object root, InstanceMap<Integer> counts) {
        // TODO configurable two cases: generate id when it's a graph (i.e. copy subtrees)
        // OR generate id when it's a **cyclic** graph
        Integer count;
        if (exists c = counts.get(root), c == -1) {
            count = idGenerator.next();// referenced more than once, give it an id
        } else {
            count = -1;
        }
        counts.put(root, count);
        if (count == -1 // not yet visited
                //&& !(root is String|Character|Integer|Boolean|Float|Null)
                && type(root).declaration.serializable) {
            //assume it's serializable serializable
            value references = sc.references(root);
            for (ref in references.references) {
                if (exists referred=ref.referred(root),
                        !referred is Integer|Float|String|Boolean) {
                    if (exists c = counts.get(referred),
                        c == -1) {
                        counts.put(referred, idGenerator.next());
                    } else {
                        assignedIdsInternal(idGenerator, referred, counts);
                    }
                }
            }
        }
    }
    
    "Ceylon Sequences are serialized as JSON arrays."
    void seq(Output visitor,
            InstanceMap<Integer> ids, 
            Type<> staticType, 
            Anything[] instance) {
        value it = iteratedType(staticType);
        visitor.onStartArray(it, staticType);
        for (Anything element in instance) {
               val(visitor, ids, it, element);
        }
        visitor.onEndArray();
    }
    
    "Ceylon Arrays are serialized as JSON arrays.
     We have to treat them differently from Sequences because unlike 
     sequences they can contain cycles because they're mutable."
    void arr(Output visitor,
        InstanceMap<Integer> ids, 
        Type<> staticType, 
        Array<out Anything> instance) {
        value it = iteratedType(staticType);
        visitor.onStartArray(it, staticType);
        // XXX The question here is how to represent a reference within an array
        // As an object {"@": 42}
        // XXX Arrays are also identifiable, so how do we represent their id
        // With a wrapper {"#": 42, value: [...]}
        for (ref in sc.references(instance).references) {
            value referred = ref.referred(instance);
            switch(ref)
            case (is Element) {
                if (is Identifiable referred,
                    instance === referred) {
                    value id2 = getId(ids, instance);
                } else {
                    val(visitor, ids, it, ref.referred(instance));
                }
            } else {
                
            }
        }
        visitor.onEndArray();
    }
    
    Integer? getId(InstanceMap<Integer> ids, Anything r) {
        if (exists r) {
            return ids.get(r);
        } else {
            return null;
        }
    }
    
    "The string to use as a key for an object that refers to 
     the given referent directly."
    function makeKeyName(Member referent) {
        value attribute = referent.attribute;
        return config.attribute(attribute)?.key else attribute.name;
    }
    
    "Ceylon Objects are serialized as JSON hashes (objects)."
    void obj(Output visitor,
            InstanceMap<Integer> ids, 
            Type<> modelType, 
            Object instance) {
        value id=getId(ids, instance);
        value clazz = type(instance);
        
        visitor.onStartObject(id, if (modelType != clazz) then clazz else null);
        if (clazz.declaration.anonymous) {
            // there's no state we care about, XXX unless it's a member!
        } else if (is Character instance) {
            visitor.onKey("character");
            visitor.onString(instance.string);
        } else {//serializable, hopefully
            for (ref in sc.references(instance)) {
                value referent = ref.key;
                switch (referent)
                case (is Member) {
                    if (exists i=ref.item , i== uninitializedLateValue) {
                        continue;
                    }
                    value id2 = getId(ids, ref.item);
                    Integer? byReference;
                    if (exists id2) {
                        if (exists id, id2 == id) {
                            byReference = id;
                        } else if (id2<0) {
                            byReference = -id2;
                        } else {
                            byReference = null;
                        }
                    } else {
                        byReference = null;
                    }
                    if (exists byReference) {
                        visitor.onKeyReference(makeKeyName(referent), byReference);
                    } else {
                        visitor.onKey(makeKeyName(referent));
                        if (exists id2, id2>0) {
                            assert(exists r = ref.item); 
                            ids.put(r,-id2);
                        }
                        val(visitor, ids, attributeType(modelType, clazz, referent.attribute)?.type else `Nothing`, ref.item);
                    }
                }
                case (is Outer) {
                    visitor.onKey("outer");
                    val(visitor, ids, `Nothing`, ref.item);// XXX not Nothing
                }
                case (is Element) {
                    "Object with an element"
                    assert(false);
                }
            }
        }
        visitor.onEndObject(id, if (modelType != clazz) then clazz else null);
    }
    
    "Serialize a value"
    void  val(Output visitor,
            InstanceMap<Integer> ids,
            Type<> staticType, 
            Anything instance) {
        if (!exists instance) {
            visitor.onNull();
        } else if (is Integer|Float instance) {
            visitor.onNumber(instance);
        } else if (is String instance) {
            visitor.onString(instance.string);
        } else if (staticType == `Character`) {
            visitor.onString(instance.string);
        } else if (is Boolean instance) {
            visitor.onBoolean(instance);
        } else if (is Anything[] instance) {
            seq(visitor, ids, staticType, instance);
        } else if (/*type(instance).declaration == `class Array`,// TODO need an isArray() in the metamodel
            // or more generally isInstanceOf(BaseType)
                is {Anything*}&Identifiable instance*/
                is Array<out Anything> instance) {
            arr(visitor, ids, staticType, instance);
        } else {
            obj(visitor, ids, staticType, instance);
        }
    }
    
    "Serialize the given [[instance]] as events on the given [[visitor]]."
    shared void serialize<Instance>(Visitor visitor, Instance instance) {
        value x = assignedIds(instance);
        print(x);
        // TODO The Discriminator, IdMaker etc might be different for different classes.
        variable Output output = VisitorOutput(visitor);
        output = PropertyIdMaker(output, visitor);
        output = TypeAttribute(output, visitor);
        output = AttributeReferencer(output, visitor);
        val(output, x, typeLiteral<Instance>(), instance);
    }
}



/*
     Need the concept of an "indirection" which should look distinct to a 
     normal hash or array
     { "#": 2, ... } // an object with id 2 (embedded in the object)
     { "#": 3, "[": [...]} an array with id 3 (wrapper object around the array). Not an object containing an array because the "[" key is impossible in a normal object
     [{"#":3}, ...] an array with id 3 (embedded embedded in the array) XX could be an empty object
     { "@foo": 2 } // an attribute referencing an id (inline)
     { "foo": {"@": 2} } // an attribute referencing an id (embedded). Must be a reference because no normal object contains a "@" key
     [ {"@": 2} ] // an array with a reference element (embedded). Must be a reference because no normal object contains a "@" key
     */

shared interface Output {
    shared formal void onStartObject(Integer? id, ClassModel<>? type);
    shared formal void onKeyReference(String key, Integer id);
    shared formal void onKey(String key);
    shared formal void onEndObject(Integer? id, ClassModel<>? type);
    shared formal void onStartArray(Type<> staticType, Type<> iteratedType);
    shared formal void onEndArray();
    shared formal void onString(String string);
    shared formal void onNumber(Integer|Float number);
    shared formal void onBoolean(Boolean boolean);
    shared formal void onNull();
}
class VisitorOutput(Visitor visitor) satisfies Output {
    shared actual default void onBoolean(Boolean boolean) {
        visitor.onBoolean(boolean);
    }
    
    shared actual default void onEndArray() {
        visitor.onEndArray();
    }
    
    shared actual default void onEndObject(Integer? id, ClassModel<>? type) {
        visitor.onEndObject();
    }
    
    shared actual default void onKey(String key) {
        visitor.onKey(key);
    }
    
    shared actual default void onKeyReference(String key, Integer id) {
        //visitor.onKey(key);
    }
    
    shared actual default void onNull() {
        visitor.onNull();
    }
    
    shared actual default void onNumber(Integer|Float number) {
        visitor.onNumber(number);
    }
    
    shared actual default void onStartArray(Type<> staticType, Type<Anything> iteratedType) {
        visitor.onStartArray();
        // XXX note we sometimes only care about the base type
        // e.g. with [1, ""] we might only care that the base type is Array, or
        // Tuple, and be happy to figure out the element types on the fly.
    }
    
    shared actual default void onStartObject(Integer? id, ClassModel<>? type) {
        visitor.onStartObject();
    }
    
    shared actual default void onString(String string) {
        visitor.onString(string);
    }
}
abstract class DelegateOutput(delegate) satisfies Output {
    shared Output delegate;
    shared actual default void onBoolean(Boolean boolean) {
        delegate.onBoolean(boolean);
    }
    
    shared actual default void onEndArray() {
        delegate.onEndArray();
    }
    
    shared actual default void onEndObject(Integer? id, ClassModel<>? type) {
        delegate.onEndObject(id, type);
    }
    
    shared actual default void onKey(String key) {
        delegate.onKey(key);
    }
    
    shared actual default void onNull() {
        delegate.onNull();
    }
    
    shared actual default void onNumber(Integer|Float number) {
        delegate.onNumber(number);
    }
    
    shared actual default void onStartArray(Type<> staticType, Type<Anything> iteratedType) {
        delegate.onStartArray(staticType, iteratedType);
    }
    
    shared actual default void onStartObject(Integer? id, ClassModel<>? type) {
        delegate.onStartObject(id, type);
    }
    
    shared actual default void onString(String string) {
        delegate.onString(string);
    }
    shared actual default void onKeyReference(String key, Integer id) {}
    
}

"Baseclass for things which augment output with type information."
abstract class DiscriminatorOutput(Output delegate) extends DelegateOutput(delegate) {
    
}
// There's a discriminator that just assumes the attribute names are sufficient to identify the type



"""Adds type information by embedding the type name as a property of the JSON 
   object:
   
       {
           "class": "Person",
           ...
       }
       
   The type name is obtained via the given [[TypeNaming]],
"""
class TypeAttribute(Output delegate, Visitor visitor, 
    TypeNaming typeNaming=fqTypeNaming, String property="class") extends DiscriminatorOutput(delegate){
    shared actual default void onStartObject(Integer? id, ClassModel<>? type) {
        super.onStartObject(id, type);
        if (exists type) {
            visitor.onKey(property);
            visitor.onString(typeNaming.name(type));
        }
    }
}
"""Adds type information by wrapping the value in an object with one item 
   to record the type name and another item to encode the 
   value itself:
   
       {
           "class": "Person", 
           "value": ...
       }
   
   The type name is obtained via the given [[TypeNaming]],
"""
class TypeObjectWrapper(Output delegate, Visitor visitor,
    TypeNaming typeNaming=fqTypeNaming, String property="class") extends DiscriminatorOutput(delegate){
    shared actual default void onStartObject(Integer? id, ClassModel<>? type) {
        if (exists type) {
            visitor.onStartObject();
            visitor.onKey(property);
            visitor.onString(typeNaming.name(type));
            visitor.onKey("value");
        }
        super.onStartObject(id, type);
        if (exists type) {
            visitor.onEndObject();
        }
    }
}

"""Adds type information by wrapping the value in an array whose first element 
   is a String representation of the type and whose second element is the 
   value itself:
   
       ["Person", {
           ...
       }]
      
   The type name is obtained via the given [[TypeNaming]],
"""
class TypeArrayWrapper(Output delegate, Visitor visitor,
    TypeNaming typeNaming=fqTypeNaming) extends DiscriminatorOutput(delegate){
    shared actual default void onStartObject(Integer? id, ClassModel<>? type) {
        if (exists type) {
            visitor.onStartArray();
            visitor.onString(typeNaming.name(type));
        }
        super.onStartObject(id, type);
        if (exists type) {
            visitor.onEndArray();
        }
    }
}

"Baseclass for things which augment output adding *identifiers* to those values that need them"
abstract class IdMaker(Output delegate) extends DelegateOutput(delegate) {
    
}
// There's an IdMaker that just assumes the some subset of keys are a primary key
"""Add an identifier to an object using the key `"#"`, for example
   
      {
         "#":42,
         ...
      }
"""
class PropertyIdMaker(Output delegate, Visitor visitor, String property="#") extends IdMaker(delegate){
    shared actual default void onStartObject(Integer? id, ClassModel<>? type) {
        super.onStartObject(id, type);
        if (exists id) {
            visitor.onKey(property);
            visitor.onNumber(id);
        }
    }
}


"Baseclass for things which augment output of references"
abstract class Referencer(Output delegate) extends DelegateOutput(delegate) {
    
}

"""Uses an `"@key"` attribute to reference another value which cannot be 
   nested (preumably due to a cycle).
   
      {
         "@referred":42,
         ...
      }
"""
class AttributeReferencer(Output delegate, Visitor visitor, String prefix="@") extends Referencer(delegate){
    shared actual void onKeyReference(String key, Integer id) {
        super.onKeyReference(key, id);
        visitor.onKey(prefix + key);
        visitor.onNumber(id);
    }
}

shared void runSer() {
    value serializer = Serializer {
         
    };
    variable value times = 2000;
    variable value hs = 0;
    for (i in 1..times) {
        value visitor = StringEmitter();
        serializer.serialize(visitor, exampleInvoice);
        value x = visitor.string;
        if (i == 1) {
            print(x);
        }
        hs+=x.hash; 
    }
    print("press enter");
    process.readLine();
    times = 8000;
    value t0 = system.nanoseconds;
    for (i in 1..times) {
        value visitor = StringEmitter();
        serializer.serialize(visitor, exampleInvoice);
        value x = visitor.string;
        if (i == 1) {
            print(x);
        }
        hs+=x.hash; 
    }
    value elapsed = (system.nanoseconds - t0)/1_000_000.0;
    print("``elapsed``ms total");
    print("``elapsed/times``ms per deserialization");
    print(hs);
}
