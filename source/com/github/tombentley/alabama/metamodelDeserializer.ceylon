import ceylon.language.meta {
    typeLiteral,
    type
}
import ceylon.json {
    Positioned,
    StringTokenizer
}
import ceylon.json.stream {
    KeyEvent,
    ArrayStartEvent,
    BasicEvent,
    ArrayEndEvent,
    ObjectStartEvent,
    ObjectEndEvent,
    StreamParser
}
import ceylon.language.meta.model {
    Type,
    Class
}
import ceylon.collection {
    ArrayList,
    HashMap
}
/*

"A contract for building instances from JSON objects."
interface ObjectBuilder {
    shared formal void bindAttribute(String attributeName, Anything attributeValue);
    shared formal Object instantiate(Type<> modelHint, Type<> keyHint);
}

"An [[ObjectBuilder]] which instantiates using named arguments."
class NamedInvocation() satisfies ObjectBuilder {
    
    // TODO support constructors too
    ArrayList<String->Anything> bindings = ArrayList<String->Anything>();
    
    shared actual void bindAttribute(String attributeName, Anything attributeValue) {
        //print("bindAttribute(``attributeName``,``attributeValue else "null"``)");
        bindings.add(attributeName->attributeValue);
    }
    shared actual Object instantiate(Type<> modelHint, Type<> keyHint) {
        Class<Object> clazz;// TODO use hints to figure out an instantiable class
        if (is Class<Object> k=keyHint) {
            clazz = k;
        } else if (is Class<Object> m=modelHint) {
            clazz = m;
        } else {
            clazz = nothing;
        }
        //print("instantiate(modelHint=``modelHint``, keyHint=``keyHint``)");
        return clazz.namedApply(bindings);
    }
}

"An [[ObjectBuilder]] which instantiates using a nullary constructor,
 and then sets attributes. This requires either defaulted variable attributes 
 or late attributes (or no attributes)."
class NullaryInvocationAndInjection() satisfies ObjectBuilder {
    
    ArrayList<String->Anything> bindings = ArrayList<String->Anything>();
    
    shared actual void bindAttribute(String attributeName, Anything attributeValue) {
        //print("bindAttribute(``attributeName``,``attributeValue else "null"`` (type=``type(attributeValue)``)");
        bindings.add(attributeName->attributeValue);
    }
    shared actual Object instantiate(Type<> modelHint, Type<> keyHint) {
        //print("instantiate(modelHint=``modelHint``, keyHint=``keyHint``)");
        Class<Object,[]> c;// TODO use hints to figure out an instantiable class
        if (is Class<Object,[]> k=keyHint) {
            c = k;
        } else if (is Class<Object,[]> k=modelHint) {
            c = k;
        } else {
            throw Exception("Unable to instantiate ``modelHint``, ``keyHint``");
        }
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


"A contract for building collection-like things from JSON arrays."
interface ContainerBuilder {
    shared formal void addElement(Anything element);
    shared formal Object instantiate(
        "A hint at the type originating from the metamodel"
        Type<> modelHint);
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
        Type<> modelHint) {
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
        Type<> modelHint) {
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
    Anything val(Type<> modelType) {
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
    
    Anything arr(Type<> modelType) {
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
    
    function obtainBuilder() {
        //ObjectBuilder builder = NamedInvocation();// TODO reuse a single instance?
        //ObjectBuilder builder = NullaryInvocationAndInjection();// TODO reuse a single instance?
        ObjectBuilder builder = NamedInvocation();// TODO reuse a single instance?
        return builder;
    }
    
    "Consume the next object from the [[stream]] and return the instance for it"
    Anything obj(Type<> modelType) {
        //print("obj(modelType=``modelType``)");
        assert(stream.next() is ObjectStartEvent);// consume initial {
        Type<> dataType;
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
        ObjectBuilder builder = obtainBuilder();
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
                value m = eliminateNull(modelType);
                value d = eliminateNull(dataType);
                return builder.instantiate(m, d);
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

shared void runOld() {
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
}*/