import ceylon.collection {
    ArrayList
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



// XXX TODO I think this can be inlines into the Deserializer
class Builder<Id>(DeserializationContext<Id> dc, clazz, id) 
        given Id satisfies Object {
    
    ClassModel<Object> clazz;
    Id id;
    
    shared void bindAttribute(Attribute<> attribute, Id attributeValue) {
        //print("bindAttribute(``attributeName``, ``attributeValue``) ``clazz``");
        //assert(exists attr = clazz.getAttribute<Nothing,Anything>(attributeName)); 
        ValueDeclaration vd = attribute.declaration;
        /*assert(is ClassOrInterfaceDeclaration c=vd1.container);
        ValueDeclaration vd;
        if (exists vd2 = c.getMemberDeclaration<ValueDeclaration>(vd1.name)) {
            vd = vd2;
        } else {
            vd = vd1;
        }*/
        if (vd.name.startsWith("@")) {
            dc.attribute(id, vd, attributeValue);
        } else {
            // XXX I can't do this, because instantiate will have returned 
            // an actual instance and I need it's ID
            dc.attribute(id, vd, attributeValue);
        }
    }
    
    shared Id->ClassModel<> instantiate() {
        if (exists ov = clazz.declaration.objectValue) {
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

"Utility for building `Sequential`s by repeatedly 
 calling [[SequenceBuilder.addElement]] and finally 
 [[SequenceBuilder.instantiate]]. 
 We don't know the sequence type until the end."
class SequenceBuilder<Id>(DeserializationContext<Id> dc, sequenceId, Id nextId(String s)) 
        satisfies ContainerBuilder<Id> 
        given Id satisfies Object {
    Id sequenceId;
    ArrayList<Id> elements = ArrayList<Id>(); 
    ArrayList<Type<>> elementTypes = ArrayList<Type<>>();
    
    "Is the given `Type` reflecting a `Tuple`?"
    function isTuple(Type<> type) {
        if (is Class<> type, type.declaration.qualifiedName.startsWith("ceylon.language::Tuple")) {
            return true;
        } else {
            return false;
        }
    }
    
    shared actual void addElement(Type<> elementType, Id elementId) {
        elements.add(elementId);
        elementTypes.add(elementType);
    }
    
    function instantiateTuple() {
        variable Id restId = nextId("for rest of Tuple (id = ``sequenceId``)");
        variable ClassModel<> restType = type(empty);
        variable Type<Anything> iteratedType = `Nothing`;
        dc.instanceValue(restId, []); //instance(arrayId, `class Array`.classApply<Anything,Nothing>(iteratedType));
        variable Id eid;
        variable value ii = elements.size-1;
        while (ii >= 0) {
                assert(exists e = elements[ii]);
                assert(exists et = elementTypes[ii]);
                eid = if (ii == 0) then sequenceId else nextId("for element index ``ii`` of Tuple (id ``sequenceId``)");
                iteratedType = et.union(iteratedType);
                value etype = `class Tuple`.classApply<Anything>(iteratedType, et, restType);
                dc.instance(eid, etype);
                dc.attribute(eid, `value Tuple.first`, e);
                dc.attribute(eid, `value Tuple.rest`, restId);
                restId = eid;
                restType = etype;
                ii--;
            }
        return sequenceId->restType;
    }
    
    shared actual Id->ClassModel<> instantiate(
        "A hint at the type originating from the metamodel"
        Type<> modelHint) {
        //dc.instanceValue(id, elements.sequence());
        if (elements.empty) {
            dc.instanceValue(sequenceId, empty);
            return sequenceId->type([]);
        } else if (elements.size == 1,
            modelHint.subtypeOf(`Singleton<Anything>`)) {
            // TODO this is also ugly loss of encapsulation like below
            // TODO what if elements.size != 1? should I just throw?
            assert(exists iteratedType = elementTypes[0]);
            value singletonType = `class Singleton`.classApply<Anything,Nothing>(iteratedType);
            dc.instance(sequenceId, singletonType);
            assert(exists elementId = elements.first);
            dc.attribute(sequenceId, `class Singleton`.getDeclaredMemberDeclaration<ValueDeclaration>("element") else nothing, elementId);
            return sequenceId->singletonType;
        } else if (isTuple(modelHint)) {
            return instantiateTuple();
        } else { 
            variable Type<Anything> iteratedType = `Nothing`;
            for (et in elementTypes) {
                iteratedType = et.union(iteratedType);
            }
            // Use an array sequence
            Id arrayId = nextId("for array of ArraySequence (id = ``sequenceId``)");
            dc.instance(arrayId, `class Array`.classApply<Anything,Nothing>(iteratedType));
            Id sizeId = nextId("for size of ArraySequence (id = ``sequenceId``)");
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
            dc.instance(sequenceId, arraySequenceType);
            dc.attribute(sequenceId, `class ArraySequence`.getDeclaredMemberDeclaration<ValueDeclaration>("array") else nothing, arrayId);
            return sequenceId->arraySequenceType;
        }
    }
}

"A [[ContainerBuilder]] for building [[Array]]s"
class ArrayBuilder<Id>(DeserializationContext<Id> dc, arrayId, Id nextId(String s)) 
        satisfies ContainerBuilder<Id> 
        given Id satisfies Object {
    Id arrayId;
    variable Integer index = 0;
    variable Type<Anything> elementType = `Nothing`;
    
    shared actual void addElement(Type<> et, Id element) {
        dc.element(arrayId, index++, element);
        elementType = type(element).union(elementType);
    }
    
    
    shared actual Id->ClassModel<> instantiate(
        "A hint at the type originating from the metamodel"
        Type<> modelHint) {
        Class<> clazz = `class Array`.classApply<Anything,Nothing>(iteratedType(modelHint));
        dc.instance(arrayId, clazz);
        value sizeId = nextId("for array of Array (id = ``arrayId``)");
        dc.instanceValue(sizeId, index);
        dc.attribute(arrayId, `value Array.size`, sizeId);
        return arrayId->clazz;
    }
}

shared class Deserializer<out Instance>(Type<Instance> clazz, 
    TypeNaming? typeNaming, String? typeProperty) {
    
    Config config = Config();
    
    value dc = deser<Integer>();
    variable value id_ = 0;
    Integer nextId(String s) {
        value id = this.id_;
        this.id_--;
        //print("allocate id ``id``: ``s``");
        return id;
    }
    
    variable LookAheadIterator<BasicEvent>? input = null;
    LookAheadIterator<BasicEvent> stream {
        assert(exists i=input);
        return i;
    }
    
    shared Instance deserialize(Iterator<BasicEvent>&Positioned input) {
        this.input = LookAheadIterator(input, 2);
        return dc.reconstruct<Instance>(val(false, null, clazz).key);
    }
    
    Type<> peekClass() {
        Type<> dataType;
        if (exists typeNaming, exists typeProperty) {
            // We ought to use any @type information we can obtain 
            // from the JSON object to inform the type we figure out for this attribute
            // but that requires (in general) that we buffer events until we reach
            // the @type, so we know the type of this object, so we can 
            // better figure out the type, of this attribute.
            // In practice we can ensure the serializer emits @type
            // as the first key, to keep such buffering to a minimum
            if (is KeyEvent k = stream.lookAhead(1),
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
        return dataType;
    }
    
    Integer? peekId() {
        Integer? id;
        if (is KeyEvent k = stream.lookAhead(1),
            k.key == "#") {
            stream.next();//consume #
            switch (idProperty = stream.next()) 
            case (is Integer){
                //print("peek id ``idProperty```");
                id = idProperty;
            }
            else {
                throw;
            }
        } else {
            id = null;
        }
        return id;
    }
    
    Boolean peekValue() {
        if (is KeyEvent k = stream.lookAhead(1),
            k.key == "value") {
            stream.next();//consume @type
            return true;
        }
        return false;
    }
    
    Integer? peekElementRef() {
        if (stream.lookAhead(1) is ObjectStartEvent,
            is KeyEvent k = stream.lookAhead(2),
            k.key == "@") {
            stream.next();//consume {
            stream.next();//consume @
            switch (idProperty = stream.next()) 
            case (is Integer){
                assert(stream.next() is ObjectEndEvent);// consume }
                return idProperty;
            }
            else {
                throw;
            }
        }
        return null;
    }
    
    "Peek at the next event in the stream and return the instance for it"
    Integer->ClassModel<> val(Boolean wrapper, Integer? id, Type<> modelType) {
        //print("val(modelType=``modelType``)");
        switch (item=stream.lookAhead(1))
        case (is ObjectStartEvent) {
            return obj(modelType);
        }
        case (is ArrayStartEvent) {
            // T is presumably some kind of X[], or Array<X> etc. 
            return arr(id, modelType);
        }
        case (is String) {
            stream.next();
            if (modelType.supertypeOf(`String`)) {
                //print("val(modelType=``modelType``): ``item``");
                value n = nextId("for string literal ``item``");
                dc.instanceValue(n, item);
                return n->`String`;
            } else if (item.size == 1 &&
                    modelType.supertypeOf(`Character`)) {
                value n = nextId("for string literal encoding character ``item``");
                dc.instanceValue(n, item.first);
                return n->`Character`;
            } else if (modelType.supertypeOf(`Float`)) {
                value n = nextId("for string literal encoding float ``item``");
                if (item == "∞") {
                    dc.instanceValue(n, infinity);
                    return n->`Float`;
                } else if (item == "-∞") {
                    dc.instanceValue(n, -infinity);
                    return n->`Float`;
                } else if (item == "NaN") {
                    dc.instanceValue(n, 0.0/0.0);
                    return n->`Float`;
                }
            }
            throw Exception("JSON String \"``item``\" cannot be coerced to ``modelType``");
        }
        case (is Integer) {
            stream.next();
            if (modelType.supertypeOf(`Integer`)) {
                //print("val(modelType=``modelType``): ``item``");
                value n = nextId("for number literal encoding integer ``item``");
                dc.instanceValue(n, item);
                return n->`Integer`;
            }
            throw Exception("JSON Number ``item`` cannot be coerced to ``modelType``");
        }
        case (is Float) {
            stream.next();
            if (modelType.supertypeOf(`Float`)) {
                //print("val(modelType=``modelType``): ``item``");
                value n = nextId("for number literal encoding float ``item``");
                dc.instanceValue(n, item);
                return n->`Float`;
            }
            throw Exception("JSON Number ``item`` cannot be coerced to ``modelType``");
        }
        case (is Boolean) {
            stream.next();
            if (modelType.supertypeOf(`true`.type)
                || modelType.supertypeOf(`false`.type)) {
                //print("val(modelType=``modelType``): ``item``");
                value n = nextId("for boolean literal ``item``");
                dc.instanceValue(n, item);
                return n->`Boolean`;
            }
            throw Exception("JSON Boolean ``item`` cannot be coerced to ``modelType``");
        }
        case (is Null) {
            stream.next();
            if (modelType.supertypeOf(`null`.type)) {
                //print("val(modelType=``modelType``): null");
                value n = nextId("for null");
                dc.instanceValue(n, item);
                return n->`Null`;
            }
            throw Exception("JSON Null null cannot be coerced to ``modelType``");
        }
        else {
            throw Exception("Unexpected event ``item``");
        }
    }
    
    Integer->ClassModel<> arr(Integer? id, Type<> modelType) {
        //print("arr(modelType=``modelType``)");
        assert(stream.next() is ArrayStartEvent);// consume initial {
        // not a SequenceBuilder, something else
        //print(modelType);
        //assert(is ClassOrInterface<Object> modelType);
        ContainerBuilder<Integer> builder;
        if (is Class<> modelType,
                modelType.declaration == `class Array`) {
            builder = ArrayBuilder<Integer>(dc, id else nextId("for array literal encoding Array"), nextId);
        } else {
            builder = SequenceBuilder<Integer>(dc, id else nextId("for array literal encoding Sequence"), nextId);
        }
        while (true) {
            switch(item=stream.lookAhead(1))
            case (is ObjectStartEvent|ArrayStartEvent|String|Null|Boolean|Float|Integer) {
                // TODO val knows the type of the thing it's creating, so we should use that as the et
                if (builder is ArrayBuilder<Integer>,
                    item is ObjectStartEvent, 
                    exists referredId = peekElementRef()) {
                    builder.addElement(`Anything`, referredId);
                } else {
                    value xx = val(false, null, iteratedType(modelType));
                    builder.addElement(xx.item, xx.key);
                }
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
            case (notStarted) {
                throw;
            }
            
        }
    }
    
    "Consume the next object from the [[stream]] and return the instance for it"
    Integer->ClassModel<> obj(Type<> modelType) {
        //print("obj(modelType=``modelType``)");
        assert(stream.next() is ObjectStartEvent);// consume initial {
        value dataType=peekClass();
        Class<Object> clazz = bestType(eliminateNull(modelType), eliminateNull(dataType));
        value id = peekId() else nextId("for object encoding ``dataType``");
        value isValue = peekValue();
        
        if (isValue) {
            // We're actually seeing a wrapper object here, so recurse
            value result = val(true, id, clazz);
            stream.next();// consume the end of the wrapper object
            return result;
        }
        Builder<Integer> builder = Builder<Integer>(dc, clazz, id);// TODO reuse a single instance?
        variable Attribute<>? attribute = null;
        variable Boolean byRef = false;
        while(true) {
            switch (item = stream.lookAhead(1))
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
                builder.bindAttribute(attr, arr(null, eliminateNull(attr.type)).key);
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
                /*if (jsonKey == "#") {
                    
                } else*/ if (jsonKey.startsWith("@")) {
                    byRef=true;
                    keyName = jsonKey[1...];
                } else {
                    byRef = false;
                    keyName = jsonKey;
                }
                // The JSON object represents a `serializable` instance
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
                if(exists attr=attribute) {
                    if (byRef, is Integer item) {
                        stream.next();
                        builder.bindAttribute(attr, item);
                    } else {
                        builder.bindAttribute(attr, val(false, null, attr.type).key);
                    }
                    attribute = null;
                } else {
                    assert(false);
                }
            }
            case (notStarted) {
                throw;
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
    if (is ClassOrInterface<Anything> containerType) {
        if (exists model = containerType.satisfiedTypes
                .narrow<Interface<Iterable<Anything>>>().first,
            exists x = model.typeArgumentList.first) {
            //print("iteratedType(containerType=``containerType``): ``x``");
            return x;
        } else if (containerType.supertypeOf(`Iterable<Anything>`)) {
            return `Anything`;
        }
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

shared Instance deserialize<Instance>(String json, 
    TypeNaming typeNaming = TypeExpressionTypeNaming()) {
    Type<Instance> clazz = typeLiteral<Instance>();
    Deserializer<Instance> deser = Deserializer<Instance>(clazz, typeNaming, "class");
    return deser.deserialize(StreamParser(StringTokenizer(json)));
    
}