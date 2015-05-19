import ceylon.collection {
    ArrayList,
    HashMap
}
import ceylon.json {
    StringTokenizer, Positioned
}
import ceylon.language.meta {
    typeLiteral,
    type
}
import ceylon.language.meta.model {
    Class,
    Value,
    Interface,
    UnionType,
    IntersectionType,
    Type,
    ClassOrInterface,
    InterfaceModel,
    Attribute,
    ClassModel
}
import ceylon.json.stream {
    ArrayStartEvent,
    ArrayEndEvent,
    KeyEvent,
    ObjectStartEvent,
    ObjectEndEvent,
    StreamParser,
    BasicEvent
}
import ceylon.language.meta.declaration {
    Package,
    ClassDeclaration,
    ValueDeclaration
}
import ceylon.language.serialization {
    DeserializationContext
}

abstract class None() of none{}
object none extends None() {}
class PeekIterator<T>(Iterator<T>&Positioned iterator) satisfies Iterator<T>&Positioned{
    variable T|Finished|None peeked = none;
    shared T|Finished peek {
        if (!is None p=peeked) {
            return p;
        } else {
            return peeked = iterator.next();
        }
    }
    shared actual T|Finished next() {
        if (!is None p=peeked) {
            peeked = none;
            return p;
        } else {
            return iterator.next();
        }
    }
    shared actual Integer column => iterator.column;
    
    shared actual Integer line => iterator.line;
    
    shared actual Integer position => iterator.position;
    // TODO
}

"A contract for building instances from JSON objects."
interface ObjectBuilder {
    shared formal void bindAttribute(String attributeName, Anything attributeValue);
    shared formal Object instantiate();
}

"An [[ObjectBuilder]] which instantiates using named arguments."
class NamedInvocation(Type modelHint, Type keyHint) satisfies ObjectBuilder {
    Class<Object> clazz;// TODO use hints to figure out an instantiable class
    if (is Class<Object> k=keyHint) {
        clazz = k;
    } else if (is Class<Object> m=modelHint) {
        clazz = m;
    } else {
        clazz = nothing;
    }
    
    // TODO support constructors too
    ArrayList<String->Anything> bindings = ArrayList<String->Anything>();
    
    shared actual void bindAttribute(String attributeName, Anything attributeValue) {
        //print("bindAttribute(``attributeName``,``attributeValue else "null"``)");
        bindings.add(attributeName->attributeValue);
    }
    shared actual Object instantiate() {
        //print("instantiate(modelHint=``modelHint``, keyHint=``keyHint``)");
        return clazz.namedApply(bindings);
    }
}

"An [[ObjectBuilder]] which instantiates using a nullary constructor,
 and then sets attributes. This requires either defaulted variable attributes 
 or late attributes (or no attributes)."
class NullaryInvocationAndInjection(Type modelHint, Type keyHint) satisfies ObjectBuilder {
    
    Class<Object,[]> c;// TODO use hints to figure out an instantiable class
    if (is Class<Object,[]> k=keyHint) {
        c = k;
    } else if (is Class<Object,[]> k=modelHint) {
        c = k;
    } else {
        throw Exception("Unable to instantiate ``modelHint``, ``keyHint``");
    }
    ArrayList<String->Anything> bindings = ArrayList<String->Anything>();
    
    shared actual void bindAttribute(String attributeName, Anything attributeValue) {
        //print("bindAttribute(``attributeName``,``attributeValue else "null"`` (type=``type(attributeValue)``)");
        bindings.add(attributeName->attributeValue);
    }
    shared actual Object instantiate() {
        //print("instantiate(modelHint=``modelHint``, keyHint=``keyHint``)");
        
        value instance = c();
        for (name->attributeValue in bindings) {
            if (exists attribute = c.getAttribute<Nothing,Anything>(name)) {
                value v = attribute.bind(instance);
                v.setIfAssignable(attributeValue);
            } else {
                throw Exception("Class ``c`` lacks attribute ``name``.");
            }
        }
        return instance;
    }
}


/*
 [
 { "@id": 1,
   "name": "rod"
   "@children": [2, 3]
 },
 { "@id": 2,
   "name": "tom",
   "@father": 1
 },
 { "@id": 3,
   "name": "ruth",
   "@father": 1
 }
 ]
 */

class S11nBuilderFactory(DeserializationContext<Integer> dc) {
    variable Integer id = 0;
    shared S11nBuilder obtainBuilder(Type<Anything> modelHint, Type<Anything> keyHint) {
        // TODO use hints to figure out an instantiable class
        Class<Object> clazz;
        if (is Class<Object> keyHint) {
            clazz = keyHint;
        } else if (is Class<Object> modelHint) {
            clazz = modelHint;
        } else {
            throw Exception("Unable to instantiate ``modelHint``, ``keyHint``");
        }
        id++;
        return S11nBuilder(dc, clazz, id);
    }
}

class S11nBuilder(DeserializationContext<Integer> dc, clazz, id) satisfies ObjectBuilder {
    
    ClassModel<Object> clazz;
    Integer id;
    
    shared actual void bindAttribute(String attributeName, Anything attributeValue) {
        assert(exists attr = clazz.getAttribute(attributeName)); 
        ValueDeclaration vd = attr.declaration;
        if (attributeName.startsWith("@")) {
            assert(is Integer attributeValue);
            dc.attribute(id, vd, attributeValue);
        } else {
            // XXX I can't do this, because instantiate will have returned 
            // an actual instance
            // and I need it's ID
            dc.attribute(id, vd, id+1);
        }
    }
    
    shared actual Object instantiate() {
        dc.instance(id, clazz);
        return dc.reconstruct(id);
    }
    
}

"A contract for building collection-like things from JSON arrays."
interface ContainerBuilder {
    shared formal void addElement(Anything element);
    shared formal Object instantiate(
        "A hint at the type originating from the metamodel"
        Type modelHint);
}

"A [[ContainerBuilder]] for building [[Sequence]]s and [[Sequential]]s."
class SequenceBuilder() satisfies ContainerBuilder {
    value sequenceType = typeLiteral<[Anything+]>();
    ArrayList<Anything> elements = ArrayList<Anything>(); 
    variable Type<Anything> elementType = `Nothing`;
    shared actual void addElement(Anything element) {
        elements.add(element);
        elementType = type(element).union(elementType);
    }
    shared actual Object instantiate(
        "A hint at the type originating from the metamodel"
        Type modelHint) {
        if (modelHint.subtypeOf(sequenceType)) {
            variable value narrowed = `function Sequence.narrow`.memberInvoke(elements, [elementType]) else [];
            //narrowed = `function Iterable.sequence`.memberInvoke(narrowed) else [];
            assert(is Object seq = `function sequence`.invoke([elementType, `Null`], narrowed));
            return seq;
        } else {
            value narrowed = `function Sequence.narrow`.memberInvoke(elements, [elementType]) else [];
            assert(is {Anything*} narrowed);
            //Anything[] result = sequence<Element>(elements.narrow<Element>()) else [];
            assert(is Object result = `function sequence`.invoke([elementType], narrowed));
            return result;
        }
    }
}

"A [[ContainerBuilder]] for building [[Array]]s"
class ArrayBuilder() satisfies ContainerBuilder {
    ArrayList<Anything> elements = ArrayList<Anything>();
    variable Type<Anything> elementType = `Nothing`;
    shared actual void addElement(Anything element) {
        elements.add(element);
        elementType = type(element).union(elementType);
    }
    shared actual Object instantiate(
        "A hint at the type originating from the metamodel"
        Type modelHint) {
        value narrowed = `function Sequence.narrow`.invoke([elementType]) else [];
        assert(exists result = `class Array`.instantiate([elementType], narrowed));
        return result;
    }
}
/*class TupleBuilder() satisfies ContainerBuilder {
    ArrayList elements
    shared actual void addElement(Anything element) {
        
    }
    shared actual T instantiate<T>(
        "A hint at the type originating from the metamodel"
        Type<T> modelHint,
        "A hint at the type originating from the serialized data" 
        Type<T>? keyHint);
}*/





shared class Deserializer<out Instance>(Type<Instance> clazz, PropertyTypeHint? typeHinting) {
    
    variable PeekIterator<BasicEvent>? input = null;
    PeekIterator<BasicEvent> stream {
        assert(exists i=input);
        return i;
    }
    
    shared Instance deserialize(Iterator<BasicEvent>&Positioned input) {
        this.input = PeekIterator(input);
        assert(is Instance result = val(clazz));
        return result;
    }
    
    "Peek at the next event in the stream and return the instance for it"
    Anything val(Type modelType) {
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
            if (is Class<String>|Type<Nothing> a=modelType) {
                //print("val(modelType=``modelType``): ``item``");
                return item;
            }
            throw Exception("JSON value ``item`` cannot be coerced to ``modelType``");
        }
        case (is Integer) {
            stream.next();
            if (is Class<Integer>|Type<Nothing> a=modelType) {
                //print("val(modelType=``modelType``): ``item``");
                return item;
            }
            throw Exception("JSON value ``item`` cannot be coerced to ``modelType``");
        }
        case (is Float) {
            stream.next();
            if (is Class<Float>|Type<Nothing> a=modelType) {
                //print("val(modelType=``modelType``): ``item``");
                return item;
            }
            throw Exception("JSON value ``item`` cannot be coerced to ``modelType``");
        }
        case (is Boolean) {
            stream.next();
            if (is Class<Boolean>|Type<Nothing> a=modelType) {
                //print("val(modelType=``modelType``): ``item``");
                return item;
            }
            throw Exception("JSON value ``item`` cannot be coerced to ``modelType``");
        }
        case (is Null) {
            stream.next();
            if (is Class<Boolean>|Type<Nothing> a=modelType) {
                //print("val(modelType=``modelType``): null");
                return item;
            }
            throw Exception("JSON value null cannot be coerced to ``modelType``");
        }
        else {
            throw Exception("Unexpected event ``item``");
        }
    }
    
    Anything arr(Type modelType) {
        //print("arr(modelType=``modelType``)");
        assert(stream.next() is ArrayStartEvent);// consume initial {
        ContainerBuilder builder = SequenceBuilder();
        while (true) {
            switch(item=stream.peek)
            case (is ObjectStartEvent|ArrayStartEvent|String|Null|Boolean|Float|Integer) {
                builder.addElement(val(iteratedType(modelType)));
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
    
    function obtainBuilder(Type modelType, Type keyType) {
        //ObjectBuilder builder = NamedInvocation();// TODO reuse a single instance?
        //ObjectBuilder builder = NullaryInvocationAndInjection();// TODO reuse a single instance?
        ObjectBuilder builder = S11nBuilder();// TODO reuse a single instance?
        return builder;
    }
    
    "Consume the next object from the [[stream]] and return the instance for it"
    Anything obj(Type modelType) {
        //print("obj(modelType=``modelType``)");
        assert(stream.next() is ObjectStartEvent);// consume initial {
        Type dataType;
        if (is PropertyTypeHint typeHinting) {
            // We ought to use any @type information we can obtain 
            // from the JSON object to inform the type we figure out for this attribute
            // but that requires (in general) that we buffer events until we reach
            // the @type, so we know the type of this object, so we can 
            // better figure out the type, of this attribute.
            // In practice we can ensure the serializer emits @type
            // as the first key, to keep such buffering to a minimum
            if (is KeyEvent k = stream.peek,
                k.eventValue == typeHinting.property) {
                stream.next();//consume @type
                if (is String typeName = stream.next()) {
                    dataType = typeHinting.naming.type(typeName);
                } else {
                    throw Exception("Expected String value for ``typeHinting.property`` property at ``stream.location``");
                }
            } else {
                dataType = `Nothing`;
            }
        } else {
            dataType = `Nothing`;
        }
        value m = eliminateNull(modelType);
        value d = eliminateNull(dataType);
        ObjectBuilder builder = obtainBuilder(m, d);
        builder.startObject(m, d);
        variable String? attributeName = null;
        while(true) {
            switch (item = stream.peek)
            case (is ObjectStartEvent) {
                assert(exists a=attributeName);
                builder.bindAttribute(a, obj(attributeType(modelType, dataType, a)));
                attributeName = null;
            }
            case (is ObjectEndEvent) {
                stream.next();// consume what we peeked
                return builder.instantiate();
            }
            case (is Finished) {
                throw Exception("unexpected end of stream");
            }
            case (is ArrayStartEvent) {
                assert(exists a=attributeName);
                builder.bindAttribute(a, arr(eliminateNull(attributeType(modelType, dataType, a))));
                attributeName = null;
            }
            case (is ArrayEndEvent) {
                "should never happen"
                assert(false);
            }
            case (is KeyEvent) {
                stream.next();// consume what we peeked
                //print("key: ``item.eventValue``");
                attributeName = item.eventValue;
            }
            case (is String|Integer|Float|Boolean|Null) {
                stream.next();// consume what we peeked
                assert(exists a=attributeName);
                builder.bindAttribute(a, item);
                attributeName = null;
            }
        }
    }
}

class Example() {
    shared late Integer i;
    shared actual String string => i.string;
}

shared void run() {
    print("press enter");
    process.readLine();
    ////print(type(`Example.i`));
    //`Example.i`(Example()).setIfAssignable(1);
    variable value times = 10000;
    value stw = Stopwatch();
    variable value d = ArrayList<DeserializationResult>(times);
    for (i in 0:times) {
        stw.start();
        value x = Deserializer {
            clazz = `Invoice`;
            typeHinting = PropertyTypeHint{
                naming = LogicalTypeNaming(HashMap{
                    "Person" -> `NullPerson`,
                    "Address" -> `NullAddress`,
                    "Item" -> `NullItem`,
                    "Product" -> `NullProduct`,
                    "Invoice" -> `NullInvoice`
                });
            }; 
        }.deserialize(StreamParser(StringTokenizer(exampleJson)));
        d.add(DeserializationResult(stw.read, x));
    }
    statDeser(d);
    
    times = 100;
    d = ArrayList<DeserializationResult>(times);
    for (i in 0:times) {
        stw.start();
        value x = Deserializer {
            clazz = `Invoice`;
            typeHinting = PropertyTypeHint{
                naming = LogicalTypeNaming(HashMap{
                    "Person" -> `NullPerson`,
                    "Address" -> `NullAddress`,
                    "Item" -> `NullItem`,
                    "Product" -> `NullProduct`,
                    "Invoice" -> `NullInvoice`
                });
            }; 
        }.deserialize(StreamParser(StringTokenizer(exampleJson)));
        d.add(DeserializationResult(stw.read, x));
    }
    statDeser(d);
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
Type attributeType(Type modelType, Type jsonType, String attributeName) {
    variable Type type = modelType.union(jsonType);
    // since we know we're finding the type of an attribute on an object
    // we know that object can't be null
    Type qualifierType = eliminateNull(type);
    ////print("attributeType(``modelType``, ``jsonType``, ``attributeName``): qualifierType: ``qualifierType``");
    Type result;
    if (is ClassOrInterface qualifierType) {
        // We want to do qualifierType.getAttribute(), but we have to do it with runtime types
        // not compile time types, so we have to do go via the metamodel.
        //value r = `function ClassOrInterface.getAttribute`.memberInvoke(qualifierType, [qualifierType, `Anything`, `Nothing`], attributeName);
        //assert(is Attribute<Nothing, Anything, Nothing> r);
        //result = r.type;
        assert(exists a = qualifierType.getAttribute<Nothing,Anything,Nothing>(attributeName));
        return a.type;
    } else {
        result = `Nothing`;
    }
    //print("attributeType(``modelType``, ``jsonType``, ``attributeName``): result: ``result``");
    return result;
}


Type eliminateNull(Type type) {
    if (is UnionType type) {
        if (type.caseTypes.size == 2,
            exists nullIndex=type.caseTypes.firstOccurrence(`Null`)) {
            assert(exists definite = type.caseTypes[1-nullIndex]);
            return definite;
        } else {
            return type;
        }
    } else {
        return type;
    }
}