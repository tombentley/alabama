import ceylon.collection {
    HashMap,
    IdentityMap,
    HashSet,
    Stability,
    Hashtable,
    unlinked
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
    uninitializedLateValue,
    References
}
import com.github.tombentley.typeparser {
    TypeParser
}
import ceylon.language.meta.declaration {
    ValueDeclaration,
    ClassOrInterfaceDeclaration,
    ClassDeclaration,
    OpenClassOrInterfaceType
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
    pretty = false,
    TypeNaming typeNaming = TypeExpressionTypeNaming()) {
    "The instance to serialize"
    Instance rootInstance;
    "Whether the returned JSON should be indented"
    Boolean pretty;
    value em = StringEmitter(pretty);
    Serializer ss = Serializer(typeNaming);
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

abstract class State(o) of top|inObject|inWrapper|inArray {
    shared Boolean o;
}
// XXX Theres no real difference between inArray and top
object top extends State(false){}
object inObject extends State(true){}
object inWrapper extends State(true){}
object inArray extends State(false){}

"""A Serializer converts a tree of Ceylon objects to JSON. 
   It's not much more than a way to introspect an recurse through an object tree, really."""
see(`function serialize`)
shared class Serializer(
    TypeNaming typeNaming = TypeExpressionTypeNaming(),
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
    void seq(State state, Output visitor,
            InstanceMap<Integer> ids, 
            Type<> staticType, 
            Anything[] instance) {
        value it = iteratedType(staticType);
        value rtType = type(instance);
        // compute sequenceType here
        // and iteratedType from that
        // unless it's a tuple, in which case the sequence type is irrelevant
        // and it's only the element types which count.
        value s2 = visitor.onStartArray(state, staticType, rtType, 0);
        for (Anything element in instance) {
               val(inArray, visitor, ids, it, element);
        }
        visitor.onEndArray(state, s2, staticType, rtType);
    }
    
    
    function markEmitted(Integer id_, InstanceMap<Integer> ids, Object instance) {
        Integer id;
        if (id_ > 0) {
            /* We need to track whether we've emitted this object yet
               once we've emitted it then future occurrences are by id 
               reference.
               Do this by negating the id once we've emitted the instance
             */
            id = -id_;
            ids.put(instance,id);
            //print("emitted ``instance``, reassigning id to ``id``");
        } else {
            id = id_;
        }
        return id;
    }
    
    "Ceylon Arrays are serialized as JSON arrays.
     We have to treat them differently from Sequences because unlike 
     sequences they can contain cycles because they're mutable."
    void arr(State state, Output visitor,
        InstanceMap<Integer> ids, 
        Type<> staticType, 
        Array<out Anything> instance) {
        value it = iteratedType(staticType);
        value rtType = type(instance);
        value id_ = getId(ids, instance);
        value s2 = visitor.onStartArray(state, staticType, rtType, id_);
        markEmitted(id_, ids, instance);
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
                    // direct cycle: array contains itself!
                    value id2 = getId(ids, instance);
                    Integer byReference = if (id2<0) then -id2 else id2;
                    visitor.onElementReference(byReference);
                } else {
                    value id2 = getId(ids, referred);
                    if (id2 < 0) {
                        visitor.onElementReference(-id2);
                    } else {
                        val(inArray, visitor, ids, it, ref.referred(instance));
                    }
                }
            }
            else {
                // This can only be Array.size, but we don't use that in the serialized form
                assert(is Member ref, ref.attribute == `value Array.size`);
            }
        }
        visitor.onEndArray(state, s2, staticType, rtType);
    }
    
    Integer getId(InstanceMap<Integer> ids, Anything r) {
        Integer id;
        if (exists r) {
            id = ids.get(r) else 0;
        } else {
            id = 0;
        }
        //print("id ``id`` has ``r else "null"``");
        return id;
    }
    
    /*Boolean inherits(ClassOrInterfaceDeclaration c1, ClassOrInterfaceDeclaration c2) {
        variable ClassOrInterfaceDeclaration c = c1;
        while (true) {
            if (c == c2) {
                return true;
            }
            if (exists et = c.extendedType) {
                c = et.declaration;
            } else {
                return false;
            }
        }
    }*/
    
    
    
    Map<Item,Key> invertMap<Key,Item>(Map<Key,Item> map) given Item satisfies Object {
        HashMap<Item,Key> result = HashMap<Item,Key>(unlinked, Hashtable(map.size));
        for(key->item in map) {
            result.put(item,key);
        }
        return result;
    }
    
    "Ceylon Objects are serialized as JSON hashes (objects)."
    void obj(State state, Output visitor,
            InstanceMap<Integer> ids, 
            Type<> modelType, 
            Object instance) {
        value id_ = getId(ids, instance);
        value clazz = type(instance);
        value s2 = visitor.onStartObject(state, id_, if (modelType != clazz) then clazz else null);
        markEmitted(id_, ids, instance);
        if (clazz.declaration.anonymous) {
            // there's no state we care about, XXX unless it's a member!
        } else {//serializable, hopefully
            value references = sc.references(instance);
            value keyNames = invertMap(config.makeKeyNames(references*.key.narrow<Member>()*.attribute));
            for (ref in references) {
                value referent = ref.key;
                switch (referent)
                case (is Member) {
                    if (exists i=ref.item , i== uninitializedLateValue) {
                        continue;
                    }
                    value refId = getId(ids, ref.item);
                    Integer byReference = if (refId<0) then -refId else refId;
                    assert(exists key = keyNames[referent.attribute]);
                    if (refId < 0) { // ref occurs > 1, but it's already been omitted
                        visitor.onKeyReference(key, byReference);
                    } else {
                        visitor.onKey(key);
                        val(inObject, visitor, ids, attributeType(modelType, clazz, referent.attribute)?.type else `Nothing`, ref.item);
                    }
                }
                case (is Outer) {
                    visitor.onKey("outer");
                    val(inObject, visitor, ids, `Nothing`, ref.item);// XXX not Nothing
                }
                case (is Element) {
                    "Object with an element"
                    assert(false);
                }
            }
        }
        visitor.onEndObject(state, s2, if (modelType != clazz) then clazz else null);
    }
    
    "Serialize a value, recursively for objects and arrays"
    void  val(State state, Output visitor,
            InstanceMap<Integer> ids,
            Type<> staticType, 
            Anything instance) {
        if (!exists instance) {
            visitor.onNull();
        } else if (is Integer|Float instance) {
            visitor.onNumber(state, instance, staticType);
        } else if (is String instance) {
            visitor.onString(instance.string);
        } else if (is Character instance) {
            visitor.onCharacter(state, instance, staticType);
        } else if (is Boolean instance) {
            visitor.onBoolean(instance);
        } else if (!instance is Empty|Range<out Anything>, is Anything[] instance) {
            seq(state, visitor, ids, staticType, instance);
        } else if (/*type(instance).declaration == `class Array`,// TODO need an isArray() in the metamodel
            // or more generally isInstanceOf(BaseType)
                is {Anything*}&Identifiable instance*/
                is Array<out Anything> instance) {
            arr(state, visitor, ids, staticType, instance);
        } else {
            obj(state, visitor, ids, staticType, instance);
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
        Output output = Output(visitor, typeNaming);
        // add decorators to the output which will add ids (using # key)...
        //output = PropertyIdMaker(output, visitor);
        // ...and @type keys...
        //output = TypeAttribute(output, visitor);
        // ... and @foo keys for things in cycles
        //output = AttributeReferencer(output, visitor);
        val(top, output, ids, typeLiteral<Instance>(), instance);
    }
}


"Adapter wrapping a JSON-[[Visitor]] used for generating JSON and satisfying
 [[Output]]."
class Output(Visitor jsonVisitor,
    TypeNaming typeNaming,
    String classKey="class",
    String idKey="#",
    String idReferencePrefix="@") {
    
    State typeWrapper(State state, Type<> type) {
        variable State result = state;
        if (!state.o) {
            jsonVisitor.onStartObject();
            result = inWrapper;
        }
        jsonVisitor.onKey(classKey);
        jsonVisitor.onString(typeNaming.name(type));
        return result;
    }
    
    State idWrapper(State state, Integer id) {
        variable State result = state;
        if (!state.o) {
            jsonVisitor.onStartObject();
            result = inWrapper;
        }
        jsonVisitor.onKey(idKey);
        assert(id > 0);
        jsonVisitor.onNumber(id);
        return result;
    }
    
    State valueWrapper(State state) {
        variable State result = state;
        if (!state.o) {
            jsonVisitor.onStartObject();
            result = inWrapper;
        }
        jsonVisitor.onKey("value");
        return result;
    }
    
    shared void onBoolean(Boolean boolean) {
        jsonVisitor.onBoolean(boolean);
    }
    
    shared void onNull() {
        jsonVisitor.onNull();
    }
    
    shared void onNumber(State state, Integer|Float number, Type<Anything> type) {
        variable value s2 = state;
        
        if (is Float number) {
            if (number.infinite) {
                if (!type.subtypeOf(`Integer|Float`)) {
                    s2 = typeWrapper(s2, `Float`);
                    s2 = valueWrapper(s2);
                }
                jsonVisitor.onString(if (number.positive) then "∞" else "-∞");
            } else if (number.undefined) {
                if (!type.subtypeOf(`Integer|Float`)) {
                    s2 = typeWrapper(s2, `Float`);
                    s2 = valueWrapper(s2);
                }
                
                jsonVisitor.onString("NaN");
                
            } else {
                jsonVisitor.onNumber(number);
            }
        } else {
            jsonVisitor.onNumber(number);
        }
        if (s2 == inWrapper) {
            jsonVisitor.onEndObject();
        }
    }
    
    shared void onString(String string) {
        jsonVisitor.onString(string);
    }
    
    shared void onCharacter(State state, Character instance, Type<Anything> staticType) {
        variable value s2 = state;
        if (staticType != `Character`) {
            s2 = typeWrapper(s2, `Character`);
            s2 = valueWrapper(s2);
        } 
        jsonVisitor.onString(instance.string);
        if (s2 == inWrapper) {
            jsonVisitor.onEndObject();
        }
    }
    
    shared State onStartObject(State state, Integer id, ClassModel<>? type) {
        variable value s2 = state;
        jsonVisitor.onStartObject();
        s2 = inObject;
        if (exists type) {
            s2 = typeWrapper(s2, type);
        }
        if (id != 0) {
            s2 = idWrapper(s2, id);
        }
        return inObject;
    }
    
    shared void onEndObject(State state, State s2, ClassModel<>? type) {
        jsonVisitor.onEndObject();
        //if (s2 == inObject && state != inObject) {
        //    jsonVisitor.onEndObject();
        //}
    }
    
    shared void onKey(String key) {
        jsonVisitor.onKey(key);
    }
    
    shared void onKeyReference(String key, Integer id) {
        jsonVisitor.onKey(idReferencePrefix+ key);
        jsonVisitor.onNumber(id);
    }
    
    shared void onElementReference(Integer id) {
        jsonVisitor.onStartObject();
        jsonVisitor.onKey(idReferencePrefix);
        jsonVisitor.onNumber(id);
        jsonVisitor.onEndObject();
    }
    
    shared State onStartArray(State state, Type<> staticType, Type<> rtType, Integer id) {
        variable value s2 = state;
        if (is ClassModel<> staticType, 
            staticType.declaration != `class Array`,
            staticType.declaration != `class Tuple`,
            staticType != rtType) {
            s2 = typeWrapper(s2, rtType);
        }
        if (id != 0) {
            s2 = idWrapper(s2, id);
        }
        if (s2 != state) {
            s2 = valueWrapper(s2);
        }
        jsonVisitor.onStartArray();
        return s2;
        
        // XXX note we sometimes only care about the base type
        // e.g. with [1, ""] we might only care that the base type is Array, or
        // Tuple, and be happy to figure out the element types on the fly.
    }
    
    shared void onEndArray(State state, State s2, Type<> staticType, Type<> rtType) {
        jsonVisitor.onEndArray();
        if (s2 == inWrapper && state != inWrapper) {
            jsonVisitor.onEndObject();
        }
    }
    
}
