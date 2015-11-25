import ceylon.collection {
    ArrayList,
    HashMap
}
import ceylon.json {
    StringTokenizer,
    Positioned
}
import ceylon.json.stream {
    ArrayStartEvent,
    ArrayEndEvent,
    KeyEvent,
    ObjectStartEvent,
    ObjectEndEvent,
    StreamParser,
    BasicEvent=Event
}
import ceylon.language.meta {
    type,
    typeLiteral
}
import ceylon.language.meta.declaration {
    ValueDeclaration
}
import ceylon.language.meta.model {
    Class,
    Interface,
    UnionType,
    Type,
    ClassOrInterface,
    ClassModel,
    Attribute
}
import ceylon.language.serialization {
    DeserializationContext,
    deser=deserialization
}

abstract class None() of none{}
object none extends None() {}

// XXX TODO I think this can be inlines into the Deserializer
class Builder<Id>(DeserializationContext<Id> dc, clazz, id) 
        given Id satisfies Object {
    
    ClassModel<Object> clazz;
    Id id;
    
    shared void bindAttribute(Attribute<> attribute, Id attributeValue) {
        //print("bindAttribute(``attributeName``, ``attributeValue``) ``clazz``");
        //assert(exists attr = clazz.getAttribute<Nothing,Anything>(attributeName)); 
        ValueDeclaration vd = attribute.declaration;
        if (attribute.string == "ceylon.language::Character.character") {
            // XXX ^^ OMG, that's horrible! This is a special case to support
            // characters like {"class"="Character", "value":"c"}
            // I.e. a wrapper object around a non-serializable class
            dc.instanceValue(id, dc.reconstruct<Character>(attributeValue));
        } else
        if (vd.name.startsWith("@")) {
            dc.attribute(id, vd, attributeValue);
        } else {
            // XXX I can't do this, because instantiate will have returned 
            // an actual instance and I need it's ID
            dc.attribute(id, vd, attributeValue);
        }
    }
    
    shared Id->ClassModel<> instantiate() {
        if (clazz == `Character`) {
            // XXX ^^ part of same hack for character
        } else if (exists ov = clazz.declaration.objectValue) {
            dc.instanceValue(id, ov.get());
        } else {
            dc.instance(id, clazz);
        }
        return id->clazz;
    }
    
}

"A contract for building collection-like things from JSON arrays."
interface ContainerBuilder<Id> 
        given Id satisfies Object {
    shared formal void addElement(Type<> et, Id element);
    shared formal Id->ClassModel<> instantiate(
        "A hint at the type originating from the metamodel"
        Type<> modelHint);
}

class SequenceBuilder<Id>(DeserializationContext<Id> dc, id, Id nextId()) 
        satisfies ContainerBuilder<Id> 
        given Id satisfies Object {
    Id id;
    ArrayList<Id> elements = ArrayList<Id>(); 
    variable Type<Anything> iteratedType = `Nothing`;
    shared actual void addElement(Type<> elementType, Id elementId) {
        elements.add(elementId);
        iteratedType = elementType.union(iteratedType);
    }
    shared actual Id->ClassModel<> instantiate(
        "A hint at the type originating from the metamodel"
        Type<> modelHint) {
        //dc.instanceValue(id, elements.sequence());
        if (elements.empty) {
            dc.instanceValue(id, empty);
            return id->type([]);
        } else if (elements.size == 1,
            modelHint.subtypeOf(`Singleton<Anything>`)) {
            value singletonType = `class Singleton`.classApply<Anything,Nothing>(iteratedType);
            dc.instance(id, singletonType);
            assert(exists elementId = elements.first);
            dc.attribute(id, `class Singleton`.getDeclaredMemberDeclaration<ValueDeclaration>("element") else nothing, elementId);
            return id->singletonType;
        }else {
            // Use an array sequence
            Id arrayId = nextId();
            dc.instance(arrayId, `class Array`.classApply<Anything,Nothing>(iteratedType));
            Id sizeId = nextId();
            dc.instanceValue(sizeId, elements.size);
            dc.attribute(arrayId, `value Array.size`, sizeId);
            variable value index = 0;
            for (e in elements) {
                dc.element(arrayId, index, e);
                index++;
            }
            // XXX very ugly loss of encapsulation here
            // we have to build in knowledge of the members of ArraySequence
            // we'd have to do the same thing to support Tuple etc.
            // we really want to support factory methods, but those will
            // require support from the SAPI so that arguments are fully constructed before
            // use => toposort. But that would permit serialization of classes 
            // which were not annotated serializable, which would be pretty neat.
            value arraySequenceType = `class ArraySequence`.classApply<Anything,Nothing>(iteratedType);
            dc.instance(id, arraySequenceType);
            dc.attribute(id, `class ArraySequence`.getDeclaredMemberDeclaration<ValueDeclaration>("array") else nothing, arrayId);
            return id->arraySequenceType;
        }
    }
}

"A [[ContainerBuilder]] for building [[Array]]s"
class ArrayBuilder<Id>(DeserializationContext<Id> dc, clazz, id) 
        satisfies ContainerBuilder<Id> 
        given Id satisfies Object {
    ClassModel<Object> clazz;
    Id id;
    variable Integer index = 0;
    variable Type<Anything> elementType = `Nothing`;
    shared actual void addElement(Type<> et, Id element) {
        dc.element(id, index++, element);
        elementType = type(element).union(elementType);
    }
    shared actual Id->ClassModel<> instantiate(
        "A hint at the type originating from the metamodel"
        Type<> modelHint) {
        dc.instance(id, clazz);
        return id->clazz;
    }
}

shared class Deserializer<out Instance>(Type<Instance> clazz, 
    TypeNaming? typeNaming, String? typeProperty) {
    
    Config config = Config();
    
    value dc = deser<Integer>();
    variable value id = 0;
    Integer nextId() {
        value n = id;
        id++;
        return n;
    }
    
    variable PeekIterator<BasicEvent>? input = null;
    PeekIterator<BasicEvent> stream {
        assert(exists i=input);
        return i;
    }
    
    shared Instance deserialize(Iterator<BasicEvent>&Positioned input) {
        this.input = PeekIterator(input);
        return dc.reconstruct<Instance>(val(clazz).key);
    }
    
    "Peek at the next event in the stream and return the instance for it"
    Integer->ClassModel<> val(Type<> modelType) {
        //print("val(modelType=``modelType``)");
        switch (item=stream.peek)
        case (is ObjectStartEvent) {
            return obj(modelType);
        }
        case (is ArrayStartEvent) {
            // T is presumably some kind of X[], or Array<X> etc. 
            return arr(modelType);
        }
        case (is String) {
            stream.next();
            if (modelType.supertypeOf(`String`)) {
                //print("val(modelType=``modelType``): ``item``");
                value n = nextId();
                dc.instanceValue(n, item);
                return n->`String`;
            } else if (item.size == 1,
                    modelType.supertypeOf(`Character`)) {
                value n = nextId();
                dc.instanceValue(n, item.first);
                return n->`Character`;
            }
            throw Exception("JSON String \"``item``\" cannot be coerced to ``modelType``");
        }
        case (is Integer) {
            stream.next();
            if (modelType.supertypeOf(`Integer`)) {
                //print("val(modelType=``modelType``): ``item``");
                value n = nextId();
                dc.instanceValue(n, item);
                return n->`Integer`;
            }
            throw Exception("JSON Number ``item`` cannot be coerced to ``modelType``");
        }
        case (is Float) {
            stream.next();
            if (modelType.supertypeOf(`Float`)) {
                //print("val(modelType=``modelType``): ``item``");
                value n = nextId();
                dc.instanceValue(n, item);
                return n->`Float`;
            }
            throw Exception("JSON Number ``item`` cannot be coerced to ``modelType``");
        }
        case (is Boolean) {
            stream.next();
            if (modelType.supertypeOf(`Boolean`)) {
                //print("val(modelType=``modelType``): ``item``");
                value n = nextId();
                dc.instanceValue(n, item);
                return n->`Boolean`;
            }
            throw Exception("JSON Boolean ``item`` cannot be coerced to ``modelType``");
        }
        case (is Null) {
            stream.next();
            if (modelType.supertypeOf(`Null`)) {
                //print("val(modelType=``modelType``): null");
                value n = nextId();
                dc.instanceValue(n, item);
                return n->`Null`;
            }
            throw Exception("JSON Null null cannot be coerced to ``modelType``");
        }
        else {
            throw Exception("Unexpected event ``item``");
        }
    }
    
    Integer->ClassModel<> arr(Type<> modelType) {
        //print("arr(modelType=``modelType``)");
        assert(stream.next() is ArrayStartEvent);// consume initial {
        // not a SequenceBuilder, something else
        //print(modelType);
        //assert(is ClassOrInterface<Object> modelType);
        SequenceBuilder<Integer> builder = SequenceBuilder<Integer>(dc, nextId(), nextId);
        //ArrayBuilder2<Integer> builder = ArrayBuilder2<Integer>(dc, `Array<String>`, nextId());
        while (true) {
            switch(item=stream.peek)
            case (is ObjectStartEvent|ArrayStartEvent|String|Null|Boolean|Float|Integer) {
                // TODO val knows the type of the thing it's creating, so we should use that as the et
                value xx = val(iteratedType(modelType));
                builder.addElement(xx.item, xx.key);
            }
            case (is ArrayEndEvent) {
                stream.next();// consume ]
                value result = builder.instantiate(modelType);
                //print("arr(modelType=``modelType``): ``result``");
                return result;
            }
            case (is ObjectEndEvent|KeyEvent|Finished) {
                throw Exception("unexpected event ``item``");
            }
            
        }
    }
    
    "Consume the next object from the [[stream]] and return the instance for it"
    Integer->ClassModel<> obj(Type<> modelType) {
        //print("obj(modelType=``modelType``)");
        assert(stream.next() is ObjectStartEvent);// consume initial {
        Type<> dataType;
        if (exists typeNaming, exists typeProperty) {
            // We ought to use any @type information we can obtain 
            // from the JSON object to inform the type we figure out for this attribute
            // but that requires (in general) that we buffer events until we reach
            // the @type, so we know the type of this object, so we can 
            // better figure out the type, of this attribute.
            // In practice we can ensure the serializer emits @type
            // as the first key, to keep such buffering to a minimum
            if (is KeyEvent k = stream.peek,
                k.key == typeProperty) {
                stream.next();//consume @type
                if (is String typeName = stream.next()) {
                    dataType = typeNaming.type(typeName);
                } else {
                    throw Exception("Expected String value for ``typeProperty`` property at ``stream.location``");
                }
            } else {
                dataType = `Nothing`;
            }
        } else {
            dataType = `Nothing`;
        }
        Class<Object> clazz = bestType(eliminateNull(modelType), eliminateNull(dataType));
        Builder<Integer> builder = Builder<Integer>(dc, clazz, nextId());// TODO reuse a single instance?
        variable Attribute<>? attribute = null;
        variable Boolean byRef = false;
        while(true) {
            switch (item = stream.peek)
            case (is ObjectStartEvent) {
                assert(exists attr=attribute);
                builder.bindAttribute(attr, obj(attr.type).key);
                attribute = null;
            }
            case (is ObjectEndEvent) {
                stream.next();// consume what we peeked
                return builder.instantiate();
            }
            case (is Finished) {
                throw Exception("unexpected end of stream");
            }
            case (is ArrayStartEvent) {
                assert(exists attr=attribute);
                builder.bindAttribute(attr, arr(eliminateNull(attr.type)).key);
                attribute = null;
            }
            case (is ArrayEndEvent) {
                "should never happen"
                assert(false);
            }
            case (is KeyEvent) {
                stream.next();// consume what we peeked
                //print("key: ``item.eventValue``");
                value jsonKey = item.key;
                String keyName;
                if (jsonKey.startsWith("@")) {
                    byRef=true;
                    keyName = jsonKey[1...];
                } else {
                    byRef = false;
                    keyName = jsonKey;
                }
                if (jsonKey in config.clazz(clazz.declaration).ignoredKeys) {
                    // TODO need to ignore the whole subtree
                    // TODO is ignoredKeys inherited? 
                    
                } else if (exists ac=config.resolveKey(clazz, keyName)){
                    // TODO lots to do here.
                    //Why we passing modelType and dataType to attributeType
                    //When we already decided to instantiate a clazz?
                    //Why it called attributeType when it returns an Attribute?
                    attribute = attributeType(eliminateNull(modelType), eliminateNull(dataType), ac.attr);
                }
                if (!attribute exists) {
                    throw Exception("Couldn't find attribute for key '``jsonKey``' on ``clazz``");
                }
            }
            case (is String|Integer|Float|Boolean|Null) {
                assert(exists attr=attribute);
                if (byRef, is Integer item) {
                    builder.bindAttribute(attr, item);
                } else {
                    builder.bindAttribute(attr, val(attr.type).key);
                }
                attribute = null;
            }
        }
    }
}


Class<Object> bestType(Type<> modelType, Type<> keyType) {
    Class<Object> clazz;// TODO use hints to figure out an instantiable class
    if (is Class<Object> k=keyType) {
        clazz = k;
    } else if (is Class<Object> m=modelType) {
        clazz = m;
    } else {
        clazz = nothing;
    }
    return clazz;
}

"Given a Type reflecting an Iterable, returns a Type reflecting the 
 iterated type or returns null if the given Type does not reflect an Iterable"
by("jvasileff")
Type<Anything> iteratedType(Type<Anything> containerType) {
    if (is ClassOrInterface<Anything> containerType,
        exists model = containerType.satisfiedTypes
                .narrow<Interface<Iterable<Anything>>>().first,
        exists x = model.typeArgumentList.first) {
        //print("iteratedType(containerType=``containerType``): ``x``");
        return x;
    }
    
    return `Nothing`;
}

"Figure out the type of the attribute of the given name that's a member of
 modelType or jsonType"
Attribute<>? attributeType(Type<> modelType, Type<> jsonType, ValueDeclaration attribute) {
    Type<> type;
    if (!jsonType.exactly(`Nothing`)) {
        type = jsonType;
    } else if (is ClassOrInterface<> modelType) {
        type = modelType;
    } else {
        type = modelType.union(jsonType);
    }
    // since we know we're finding the type of an attribute on an object
    // we know that object can't be null
    Type<> qualifierType = eliminateNull(type);
    ////print("attributeType(``modelType``, ``jsonType``, ``attributeName``): qualifierType: ``qualifierType``");
    if (is ClassOrInterface<> qualifierType) {
        // We want to do qualifierType.getAttribute(), but we have to do it with runtime types
        // not compile time types, so we have to do go via the metamodel.
        //value r = `function ClassOrInterface.getAttribute`.memberInvoke(qualifierType, [qualifierType, `Anything`, `Nothing`], attributeName);
        //assert(is Attribute<Nothing, Anything, Nothing> r);
        //result = r.type;
        // XXX this is wrong: It doesn't cope with colliding attrs or non-shared attrs
        if (attribute.shared) {
            return qualifierType.getAttribute<Nothing,Anything,Nothing>(attribute.name);
        } else {
            if (is ClassModel<> qualifierType) {
                variable ClassModel<>? q = qualifierType;
                while(exists p=q) { 
                    if (p.declaration == attribute.container) {
                        return p.getDeclaredAttribute<Nothing,Anything,Nothing>(attribute.name);
                    }
                    q = q?.extendedType;
                }
            }
            throw Exception("Couldn't find ``attribute`` in ``qualifierType``");
        }
    } else {
        return null;
    }
}


Type<> eliminateNull(Type<> type) {
    if (is UnionType<> type) {
        if (type.caseTypes.size == 2,
            exists nullIndex=type.caseTypes.firstIndexWhere((e) => e == `Null`)) {
            assert(exists definite = type.caseTypes[1-nullIndex]);
            return definite;
        } else {
            return type;
        }
    } else {
        return type;
    }
}

shared Instance deserialize<Instance>(String json) {
    Type<Instance> clazz = typeLiteral<Instance>();
    Deserializer<Instance> deser = Deserializer<Instance>(clazz, fqTypeNaming, "class");
    return deser.deserialize(StreamParser(StringTokenizer(json)));
    
}