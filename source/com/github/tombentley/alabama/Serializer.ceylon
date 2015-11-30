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
    typeLiteral,
    classDeclaration
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
shared String serialize<Instance>(
    rootInstance, 
    pretty = false) {
    "The instance to serialize"
    Instance rootInstance;
    "Whether the returned JSON should be indented"
    Boolean pretty;
    value em = StringEmitter(pretty);
    Serializer ss = Serializer();
    ss.serialize<Instance>(em, rootInstance);
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
    Integer singleReference = -1;
    
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
    
    "Recursively walk the object graph from [[root]], assigning ids to 
     instances that need them, recorded in [[counts]]."
    void assignedIdsInternal(IdGenerator idGenerator, Object root, InstanceMap<Integer> counts) {
        // TODO configurable two cases: generate id when it's a graph (i.e. copy subtrees)
        // OR generate id when it's a **cyclic** graph
        Integer count;
        if (exists c = counts.get(root), c == singleReference) {
            count = idGenerator.next();// referenced more than once, give it an id
        } else {
            count = singleReference;
        }
        counts.put(root, count);
        if (count == singleReference // not yet visited
                //&& !(root is String|Character|Integer|Boolean|Float|Null)
                && classDeclaration(root).serializable) {
            //assume it's serializable
            value references = sc.references(root);
            for (ref in references.references) {
                if (exists referred=ref.referred(root),
                        !referred is Integer|Float|String|Boolean|Tuple<Anything,Anything,Anything[]>) {
                    // Tuple is not Identifiable and because it outputs as [1,2] we can't easily add a # key for an id
                    // so by not assigning it an id we include each occurrence of a tuple as a subtree
                    // even if it's just a single instance!
                    if (exists c = counts.get(referred)) {
                        if (c == singleReference) {
                            counts.put(referred, idGenerator.next());
                        }
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
        value rtType = type(instance);
        // compute sequenceType here
        // and iteratedType from that
        // unless it's a tuple, in which case the sequence type is irrelevant
        // and it's only the element types which count.
        visitor.onStartArray(staticType, rtType);
        for (Anything element in instance) {
               val(visitor, ids, it, element);
        }
        visitor.onEndArray(staticType, rtType);
    }
    
    "Ceylon Arrays are serialized as JSON arrays.
     We have to treat them differently from Sequences because unlike 
     sequences they can contain cycles because they're mutable."
    void arr(Output visitor,
        InstanceMap<Integer> ids, 
        Type<> staticType, 
        Array<out Anything> instance) {
        value it = iteratedType(staticType);
        value rtType = type(instance);
        visitor.onStartArray(staticType, rtType);
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
        visitor.onEndArray(staticType, rtType);
    }
    
    Integer getId(InstanceMap<Integer> ids, Anything r) {
        if (exists r) {
            return ids.get(r) else 0;
        } else {
            return 0;
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
        value id_=getId(ids, instance);
        value clazz = type(instance);
        
        visitor.onStartObject(id_, if (modelType != clazz) then clazz else null);
        Integer id;
        if (id_ > 0) {
            /* We need to track whether we've emitted this object yet
               once we've emitted it then future occurrences are by id 
               reference.
               Do this by negating the id once we've emitted the instance
             */
            id = -id_;
            ids.put(instance,-id_);
            //print("Updating ``ids``");
        } else {
            id = id_;
        }
        
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
                    value refId = getId(ids, ref.item);
                    Integer byReference;
                    if (refId<0) {
                        byReference = -refId;
                    } else {
                        byReference = refId;
                    }
                    //print("``referent.attribute`` ``instance```:  ``id_`` ``id`` ``refId``");
                    if (refId < 0) { // ref occurs > 1, but it's already been omitted
                        //print("``referent.attribute`` by reference");
                        visitor.onKeyReference(makeKeyName(referent), byReference);
                    } else {
                        //print("``referent.attribute`` by value");
                        visitor.onKey(makeKeyName(referent));
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
    
    "Serialize a value, recursively for objects and arrays"
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
        } else if (!instance is Empty|Range<out Anything>, is Anything[] instance) {
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
        // visit the graph assigning ids to things that can't be included 
        // by nesting
        // TODO allow skipping this if caller promises instance graph is not cyclic?
        value ids = assignedIds(instance);
        //print(ids);
        // TODO The Discriminator, IdMaker etc might be different for different classes.
        Output output = Output(visitor);
        // add decorators to the output which will add ids (using # key)...
        //output = PropertyIdMaker(output, visitor);
        // ...and @type keys...
        //output = TypeAttribute(output, visitor);
        // ... and @foo keys for things in cycles
        //output = AttributeReferencer(output, visitor);
        val(output, ids, typeLiteral<Instance>(), instance);
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

abstract class TypeInfo() {
    shared default void beforeStartObject(TypeNaming typeNaming, Type<>? type, Visitor visitor) {}
    shared default void afterStartObject(TypeNaming typeNaming, Type<>? type, Visitor visitor) {}
    shared default void beforeEndObject(TypeNaming typeNaming, Type<>? type, Visitor visitor) {}
    shared default void afterEndObject(TypeNaming typeNaming, Type<>? type, Visitor visitor) {}
}
object noTypeInfo extends TypeInfo() {}
class InlineAttributeTypeInfo(String typeKey="class") extends TypeInfo() {
    shared actual void afterStartObject(TypeNaming typeNaming, Type<>? type, Visitor visitor) {
        if (exists type) {
            visitor.onKey(typeKey);
            visitor.onString(typeNaming.name(type));
        }
    }
}
class WrapperObjectTypeInfo(String typeKey="class", String valueKey="value") extends TypeInfo() {
    shared actual void beforeStartObject(TypeNaming typeNaming, Type<>? type, Visitor visitor) {
        if (exists type) {
            visitor.onStartObject();
            visitor.onKey(typeKey);
            visitor.onString(typeNaming.name(type));
            visitor.onKey(valueKey);
        }
    }
    shared actual void afterEndObject(TypeNaming typeNaming, Type<>? type, Visitor visitor) {
        if (exists type) {
            visitor.onEndObject();
        }
    }
}
object wrapperArrayTypeInfo extends TypeInfo() {
    shared actual void beforeStartObject(TypeNaming typeNaming, Type<>? type, Visitor visitor) {
        if (exists type) {
            visitor.onStartArray();
            visitor.onString(typeNaming.name(type));
        }
    }
    shared actual void afterEndObject(TypeNaming typeNaming, Type<>? type, Visitor visitor) {
        if (exists type) {
            visitor.onEndArray();
        }
    }
}

"Adapter wrapping a JSON-[[Visitor]] used for generating JSON and satisfying
 [[Output]]."
class Output(Visitor visitor,
    TypeNaming typeNaming=fqTypeNaming, 
    String idKey="#",
    String idReferencePrefix="@",
    TypeInfo typeInfo=InlineAttributeTypeInfo()) {
    
    shared default void onBoolean(Boolean boolean) {
        visitor.onBoolean(boolean);
    }
    
    shared default void onStartObject(Integer id, ClassModel<>? type) {
        typeInfo.beforeStartObject(typeNaming, type, visitor);
        visitor.onStartObject();
        if (id != 0) {
            visitor.onKey(idKey);
            visitor.onNumber(id);
        }
        typeInfo.afterStartObject(typeNaming, type, visitor);
    }
    
    shared default void onEndObject(Integer? id, ClassModel<>? type) {
        typeInfo.beforeEndObject(typeNaming, type, visitor);
        visitor.onEndObject();
        typeInfo.afterEndObject(typeNaming, type, visitor);
    }
    
    shared default void onKey(String key) {
        visitor.onKey(key);
    }
    
    shared default void onKeyReference(String key, Integer id) {
        visitor.onKey(idReferencePrefix+ key);
        visitor.onNumber(id);
    }
    
    shared default void onNull() {
        visitor.onNull();
    }
    
    shared default void onNumber(Integer|Float number) {
        visitor.onNumber(number);
    }
    
    shared default void onStartArray(Type<> staticType, Type<> rtType) {
        WrapperObjectTypeInfo? w;
        if (is ClassModel<> staticType, 
            staticType.declaration != `class Array`,
            staticType.declaration != `class Tuple`,
            staticType != rtType) {
            value w1 = WrapperObjectTypeInfo();
            w1.beforeStartObject(typeNaming, rtType, visitor);
            w=w1;
        } else {
            w = null;
        }
        visitor.onStartArray();
        if (exists w) {
            w.afterStartObject(typeNaming, rtType, visitor);
        }
        // XXX note we sometimes only care about the base type
        // e.g. with [1, ""] we might only care that the base type is Array, or
        // Tuple, and be happy to figure out the element types on the fly.
    }
    
    shared default void onEndArray(Type<> staticType, Type<> rtType) {
        WrapperObjectTypeInfo? w;
        if (is ClassModel<> staticType, 
            staticType.declaration != `class Array`,
            staticType.declaration != `class Tuple`,
            staticType != rtType) {
            value w1 = WrapperObjectTypeInfo();
            w1.beforeEndObject(typeNaming, rtType, visitor);
            w=w1;
        } else {
            w = null;
        }
        visitor.onEndArray();
        if (exists w) {
            w.afterEndObject(typeNaming, rtType, visitor);
        }
    }
    
    shared default void onString(String string) {
        visitor.onString(string);
    }
}
