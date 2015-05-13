import ceylon.language.meta.declaration {
    ValueDeclaration
}
import ceylon.language.meta {
    type
}
import ceylon.collection {
    HashMap,
    unlinked,
    Hashtable,
    LinkedList,
    Queue,
    Stack
}
import ceylon.language.meta.model {
    Attribute,
    ClassModel,
    Class,
    MemberClass
}
import ceylon.json {
    Visitor
}
void visitGraph<Id>(GraphVisitor<Id> visitor){}

interface GraphVisitor<Id> {
    "The attribute of the given instance will be visited. 
     An identifier for the instance should be returned."
    shared formal Id startObject(Object instance);
    "The given attribute of the given instance (which has the given id) is being visited"
    shared formal Boolean attribute(Id id, Object instance, ValueDeclaration attribute, Anything attributeValue);
    "[[attribute]] has been invoked for all the attributes of the given instance."
    shared formal void endObject(Id id, Object instance);
    
    "The elements of the given array will be visited. 
     An identifier for the array should be returned."
    shared formal Id startArray(Object instance);
    "The given element of the given instance (which has the given id) is being visited."
    shared formal Boolean element(Id id, Object instance, Integer index, Anything elementValue);
    "[[element]] has been invoked for all the elements of the given instance."
    shared formal void endArray(Id id, Object instance);
}

interface Walker {
    shared formal void walk(Object start);
}
class VariableWalker<Id>(GraphVisitor<Id> v) 
        satisfies Walker {
    HashMap<Object, Id> ids = HashMap<Object, Id>();
    shared actual void walk(Object start) {
        Id id;
        if (ids.contains(start)) {
            assert(is Id i = ids[start]);
            id = i;
        } else {
            id = v.startObject(start);
            ids.put(start, id);
        }
        for (Attribute<Anything> a in type(start).attributes) {
            if (a.declaration.variable
                    || a.declaration.late) {
                value av = a(start).get();
                if (v.attribute(id, start, a, av)) {
                    walk(av);
                }
            }
        }
        
        v.endObject(id, start);
    }
}
class ParameterWalker<Id>(GraphVisitor<Id> v)
        satisfies Walker {
    HashMap<Object, Id> ids = HashMap<Object, Id>();
    shared actual void walk(Object start) {
        Id id;
        if (ids.contains(start)) {
            assert(is Id i = ids[start]);
            id = i;
        } else {
            id = v.startObject(start);
            ids.put(start, id);
        }
        value classModel = type(start);
        for (Attribute<Anything> a in classModel.attributes) {
            if (a.container == classModel
                    && a.declaration.parameter) {
                value av = a(start).get();
                if (v.attribute(id, start, a, av)) {
                    walk(av);
                }
            }
        }
        v.endObject(id, start);
    }
}
class SerializableStateWalker<Id>(GraphVisitor<Id> v)
        satisfies Walker {
    // TODO this would be implemented in the serialization API using an objects knowledge of its own state
    
    // XXX all the walkers are basically the same, in that they have some way 
    // to introspect an object, some way to filter that
    // and they implement some kind of traversal order.
}

class JsonSerializingVisitor(Visitor visitor) satisfies GraphVisitor<Null> {
    shared actual Null startObject(Object instance) {
        switch(instance)
        case (is String) {
            visitor.onString(instance);
        }
        case (is Integer|Float) {
            visitor.onNumber(instance);
        }
        case (is Boolean) {
            visitor.onBoolean(instance);
        }
        else {
            visitor.onStartObject();
        }
        return null;
        // this only works if I know we're going a depth first traversal
        // so we need types to express that that's how a particular walker will visit a graph
    }
    
    shared actual Boolean attribute(Null id, Object instance, ValueDeclaration attribute, Anything attributeValue) {
        visitor.onKey(attribute.name);
        // this only works if I know that startObject/startArray will be called next
        return true;
    }
    
    shared actual void endObject(Null id, Object instance) {
        visitor.onEndObject();
    }
    
    shared actual Null startArray(Object instance) {
        visitor.onStartArray();
        return null;
    }
    
    shared actual Boolean element(Null id, Object instance, Integer index, Anything elementValue) {
        // TODO it's meaningless to not visit some particular element of an array
        // so why does this return boolean?
        return true;
    }
    
    shared actual void endArray(Null id, Object instance) {
        visitor.onEndArray();
    }
}

interface Deser<Id> {
    """The given [[instanceId]] refers to an instance of the given class """
    shared formal void instance(Id instanceId, Class clazz);

    """The given [[instanceId]] refers to an instance of the given 
       member class, which is a member of instance with the given [[containerId]]."""
    shared formal void memberInstance(Id containerId, Id instanceId, MemberClass<Anything> clazz);

    """The instance with the given [[instanceId]] has an attribute whose 
       value has the given id."""
    shared formal void attribute(Id instanceId, ValueDeclaration attribute, Id attributeValueId);
    // XXX ^^ this here allows us to refer to an attribute's value before we know it's class (before we've instantiated it)
    // that might allow a single parse
    
    """The array instance with the given [[instanceId]] has the element 
       at the given index whose value has the given id."""
    shared formal void element(Id instanceId, Integer index, Id elementValueId);
    
    """The given instance has the given value."""
    shared formal void instanceValue(Id instanceId, Anything instanceValue);
    
    """Get the instance with the given [[instanceId]] reconstructing it 
       if necessary."""
    shared formal Instance reconstruct<Instance>(Id instanceId);
}

//abstract class None() of none {}
//object none extends None() {
//    shared actual String string ="none";
//}

"Holder of the state of partially initialized objects during deserialization.
 
 After a Partial instance has been constructed it has its state specified as follows:
 
 * Its type specified
 * Its container type specified (for member types) and/or
 * Any of the instances it references specified
 
 Crucially the above can happen in any order.
 
 At some later time is can be [[Partial.instantiate|instantiated]], so that 
 it actually holds a reference to a partially constructed instance.
 
 Then at a still later time it can be [[Partial.initialize|initialized]], 
 so that it refers to other instances. (Care must still be taken at this 
 point because until [[Deser.reconstruct]] has finished normally
 the graph of reachable instances as a whole includes some instances which 
 have not been initialized.
 "
/*
 each serializable class implements:
   Constructor($Serialization$, TypeDescriptor) {}
   static String[] attributeNames();// or static void attributeNames
   static MethodHandle setter(String attributeName);
 */
abstract class Partial() {
    "The class, if we know it"
    shared late ClassModel clazz;
    "The containing instance (a partial for it, or the instance itself), or none"
    shared variable Anything container = none;
    "The instance, if it has been constructed yet, or none"
    variable Anything instance_ = null;
    "The state, mapping attributes (for objects) or indexes (for arrays) to either
     a Partial or an actual instance"
    variable HashMap<String|Integer, Anything>? state = HashMap<String|Integer, Anything> { 
        stability = unlinked;
        hashtable = Hashtable(2);
    };
    
    shared void addState(String|Integer attrOrIndex, Anything partialOrComplete) {
        "instance already initialized, too late to add state"
        assert(exists s=state);
        s.put(attrOrIndex, partialOrComplete);
    }
    
    "Creates and initializes the [[instance_]] using backend-specific reflection."
    shared formal void instantiate();
    
    "Initializes the [[instance_]] using backend-specific reflection, then sets the state to null."
    shared formal void initialize();
    
    shared Boolean instantiated => instance_ exists;
    shared Boolean initialized => !state exists;
    
    shared Anything instance() {
        assert(instantiated && initialized);
        return instance_;
    }
    
    shared {Anything*} refersTo {
        assert(exists s=state);
        return s.keys;
    }
}
native class PartialImpl() extends Partial() {
    shared actual native void instantiate() {
        /*
         "instance already instantiated"
         assert(!instance_ exists);
         java.lang.Class c = getJavaClass(clazz);
         Object instance = c.invoke(¡(Serialization)null¡);
         setInstance_(instance);
         */
    }
    
    shared actual native void initialize() {
        /*
         if (!instance_ exists) {
            instantiate();
         }
         if (getInstance_() instanceof Array) {
            Map<Integer, Object> state = getState();
             Integer[] attributeNames = instance.attributeNames();
             if (state.size() != attributeNames.length) {
                 missingNames = new HashSet(state.keySet());
                 missingNames.removeAll(Arrays.asList(attributeNames));
                 throw new Exception("lacking state for attributes " + missingNames);
             }
             for (String attributeName : attributeNames) {
                 MethodHandle mh = instance.setter(attributeName);
                 mh.invoke(state.get(attributeName);
             }
         } else {
             Map<String, Object> state = getState();
             String[] attributeNames = instance.attributeNames();
             if (state.size() != attributeNames.length) {
                 missingNames = new HashSet(state.keySet());
                 missingNames.removeAll(Arrays.asList(attributeNames));
                 throw new Exception("lacking state for attributes " + missingNames);
             }
             for (String attributeName : attributeNames) {
                 MethodHandle mh = instance.setter(attributeName);
                 Object referred = state.get(attributeName);
                 if (referred instanceof Partial) {
                     referred = referred.leak();
                 }
                 mh.invoke(referred);
             }
         }
         state = null;
         */
    }
    
    
}
class DeserImpl<Id>() satisfies Deser<Id> 
        given Id satisfies Object {
    value instances = HashMap<Id, Anything>();
    
    shared actual void attribute(Id instanceId, ValueDeclaration attribute, Id attributeValueId) {
        attributeOrElement(instanceId, attribute.name, attributeValueId);
    }
    void attributeOrElement(Id instanceId, String|Integer attributeOrIndex, Id attributeValueId) {
        Anything referred;
        switch(r=instances[attributeValueId])
        case (is Null){
            value p = PartialImpl();
            instances.put(attributeValueId, p);
            referred = p;
        }
        else {//referred is an instance or a partial
            referred = r;
        }
        Partial referring;
        switch(r=instances[instanceId])
        case (is Null){
            value p = PartialImpl();
            instances.put(instanceId, p);
            referring = p;
        }
        case (is Partial) {
            referring = r;
        }
        else {//referring is an instance
            throw Exception("instance referred to by id ``instanceId`` already complete so cannot reference instance referred to by id ``attributeValueId``");
        }
        referring.addState(attributeOrIndex, referred);
    }
    
    shared actual void element(Id instanceId, Integer index, Id elementValueId) {
        attributeOrElement(instanceId, index, elementValueId);
    }
    
    shared actual void instance(Id instanceId, Class<Anything,Nothing> clazz) {
        commonInstance(instanceId, clazz);
    }
    Partial commonInstance(Id instanceId, ClassModel<Anything,Nothing> clazz) {
        Partial partial;
        switch(r=instances[instanceId])
        case (is Null) {
            value p = PartialImpl();
            instances.put(instanceId, p);
            partial = p;
        }
        case (is Partial) {
            partial = r;
        }
        else {// an instance
            //assert(clazz.typeOf(r));
            throw;
        }
        partial.clazz = clazz;
        return partial;
    }
    
    shared actual void memberInstance(Id containerId, Id instanceId, MemberClass<Anything,Anything,Nothing> clazz) {
        Partial partial = commonInstance(instanceId, clazz);
        Anything container;
        switch(r=instances[instanceId])
        case (is Null) {
            value p = PartialImpl();
            instances.put(instanceId, p);
            container = p;
        }
        else {
            container = r;
        }
        partial.container = container;
    }
    
    shared actual void instanceValue(Id instanceId, Anything instanceValue) {
        "id already in use"
        assert(!instanceId in instances.keys);
        assert(!is Partial instanceValue);
        instances.put(instanceId, instanceValue);
    }
    
    shared actual Instance reconstruct<Instance>(Id instanceId) {

        LinkedList<Anything> queue = LinkedList<Anything>();
        queue.push(instances[instanceId]);
        while (!queue.empty){
            switch(r=queue.pop())
            case (is Null) {
                throw Exception("unknown id ``instanceId``");
            }
            case (is Partial) {
                r.instantiate();
                // push the referred things on to the stack
                // but only if they haven't yet been instantiated
                for (referred in r.refersTo) {
                    if (is Partial referred,
                        !referred.instantiated) {
                        queue.push(referred);
                    }
                }
            } else {
                // it's an instance already, nothing to do
            }
        }
        // we now have real instances for everything reachable from instanceId
        // so now we can inject the state...
        queue.push(instances[instanceId]);
        while (!queue.empty){
            switch(r=queue.pop())
            //case (is Null) {
            //    throw Exception("unknown id ``instanceId``");
            //}
            case (is Partial) {
                r.initialize();
                // push the referred things on to the stack
                // but only if they haven't yet been initialized
                for (referred in r.refersTo) {
                    if (is Partial referred,
                        !referred.initialized) {
                        queue.push(referred);
                    }
                }
            } else {
                // it's an instance already, nothing to do
            }
        }
        
        switch(r=instances[instanceId])
        //case (is Null) {
        //    throw Exception("unknown id ``instanceId``");
        //}
        case (is Partial) {
            assert(is Instance result=r.instance());
            return result;
        }
        else {
            assert(is Instance r);
            return r;
        }
        
    }
}


/*
interface Deser2 {
    """The given [[instanceId]] refers to an instance of the given class """
    shared formal Partial2<Id, Instance> instance<Id, Instance>(Id instanceId, Class<Instance> clazz);
    
    """The given [[instanceId]] refers to an instance of the given 
       member class, which is a member of instance with the given [[containerId]]."""
    shared formal Partial2<Id, Instance> memberInstance<Id, Outer, Instance>(Partial2<Id, Outer> container, Id instanceId, MemberClass<Outer, Instance> clazz);
    
    """The given instance has the given value."""
    shared formal Partial2<Id, Instance> instanceValue<Id, Instance>(Id instanceId, Instance instanceValue);
    
    
}

interface Partial2<Id, Instance> {
    shared formal Id id;
    """The instance with the given [[instanceId]] has an attribute whose value has the given id."""
    shared formal void attribute(ValueDeclaration attribute, Partial2<Id, Anything> attributeValueId);
    // XXX ^^ this here requires we have a Partial2 instance for the referred thing
    // we which means bottom up (in the case of tree) or double visit (in the case of graph)
    // first to obtain Partials then to use them.
    
    """The array instance with the given [[instanceId]] has the element at the given index whose value has the given id."""
    shared formal void element(Integer index, Partial2<Id, Anything> elementValueId);
    
    """Get the instance with the given [[instanceId]] reconstructing it 
       if necessary."""
    shared formal Instance reconstruct();
}*/