import ceylon.test {
    test,
    assertEquals,
    fail,
    assertTrue
}

import com.github.tombentley.alabama {
    Config,
    omittedAttribute,
    deserialize,
    serialize,
    aliasedKey,
    key,
    ignoredKeys
}
import ceylon.language.meta {
    type,
    typeLiteral
}

test
shared void serializeInvoice() {
    assertEquals(serialize(exampleInvoice, true),
                 """{
                     "bill": {
                      "name": "Mr Pig",
                      "address": {
                       "lines": [
                        "3 Pigs House",
                        "The Farm"
                       ],
                       "postCode": "3PH"
                      }
                     },
                     "deliver": {
                      "name": "Mr Pig",
                      "address": {
                       "lines": [
                        "3 Pigs House",
                        "The Farm"
                       ],
                       "postCode": "3PH"
                      }
                     },
                     "items": [
                      {
                       "product": {
                        "sku": "123",
                        "description": "Bag of sand",
                        "unitPrice": 2.34,
                        "salesTaxRate": 0.2
                       },
                       "quantity": 4.0
                      },
                      {
                       "product": {
                        "sku": "876",
                        "description": "Bag of cement",
                        "unitPrice": 3.57,
                        "salesTaxRate": 0.2
                       },
                       "quantity": 1.0
                      }
                     ]
                    }""");
}


String exampleJson = """{ 
                          "bill": {
                            "name": "Yogi Bear",
                            "address": {
                              "postCode": "123123",
                              "lines": ["Yellowstone", "California"]
                            }
                          },
                          "deliver": {
                            "name": "Bobo",
                            "address": {
                              "lines": ["Yellowstone", "California"],
                              "postCode": "23123"
                            }
                          },
                          "items": [
                            {
                              "product": {
                                "sku": "567",
                                "description": "Honey",
                                "unitPrice": 4.50,
                                "salesTaxRate": 0.2
                              },
                              "quantity": 4.0
                            },
                            {
                              "product": {
                                "sku": "123",
                                "description": "Picnic baskets",
                                "unitPrice": 10.99,
                                "salesTaxRate": 0.2
                              },
                              "quantity": 1.0
                            }
                          ]
                          }
                          """;


//logicalName("Example")
ignoredKeys("gee")
class AnnotationsExample(bar, baz) {
    key("foo")
    aliasedKey("fooble")
    shared String bar;
    
    omittedAttribute
    shared String baz;
}

ignoredKeys("foo")
class AnnotationsExample2(bar) {
    key("foo")
    shared String bar;
}

ignoredKeys("foo")
class AnnotationsExample3(bar) {
    aliasedKey("foo")
    shared String bar;
}

class AnnotationsExample4(bar) {
    aliasedKey("fooble")
    shared String bar;
}
class AnnotationsExample5(bar) {
    omittedAttribute
    aliasedKey("fooble")
    shared String bar;
}
class AnnotationsExample6(bar) {
    omittedAttribute
    key("fooble")
    shared String bar;
}

test
shared void readingAnnotations() {
    value cfg = Config();
    variable value cs = cfg.clazz(`class AnnotationsExample`);
    assert(`class AnnotationsExample` == cs.clazz);
    assert(["gee"] == cs.ignoredKeys);
    value xx = `value AnnotationsExample.baz` in cs.omittedAttributes;
    assert(`value AnnotationsExample.baz` in cs.omittedAttributes);
    assert(exists b= cs.keys["foo"]);
    assert(exists b2= cs.keys["fooble"]);
    assert(b===b2);
    assert(b.attr == `value AnnotationsExample.bar`);
    assert(b.key == "foo");
    
    try {
        cs = cfg.clazz(`class AnnotationsExample2`);
        fail("excepted exception");
    } catch (AssertionError e) {
        assertEquals(e.message, """ignored keys cannot also be keys: foo""");
    }
    try {
        cs = cfg.clazz(`class AnnotationsExample3`);
        fail("excepted exception");
    } catch (AssertionError e) {
        assertEquals(e.message, "ignored keys cannot also be keys: foo");
    }
    
    cs = cfg.clazz(`class AnnotationsExample4`);
    assert(exists b3= cs.keys["bar"]);
    assert(exists b4= cs.keys["fooble"]);
    assert(b3===b4);
    assert(b3.attr == `value AnnotationsExample4.bar`);
    assert(b3.key == "bar");
    
    cs = cfg.clazz(`class AnnotationsExample5`);
    cs = cfg.clazz(`class AnnotationsExample6`);
}

test
shared void serializeString() {
    assertEquals(serialize("string"), """"string"""");
}

test
shared void serializeCharacter() {
    assertEquals(serialize('c'), """"c"""");
    assertEquals(serialize<Object>('c'), """{"class":"ceylon.language::Character","value":"c"}""");
}
test
shared void serializeInteger() {
    assertEquals(serialize(42), """42""");
}
test
shared void serializeFloat() {
    assertEquals(serialize(42.0), """42.0""");
}
test
shared void serializeBoolean() {
    assertEquals(serialize(true), """true""");
    assertEquals(serialize(false), """false""");
}
test
shared void serializeNull() {
    assertEquals(serialize(null), """null""");
}

serializable class Generic<Element>(element) {
    shared Element element;
    shared actual String string => "Generic<``typeLiteral<Element>()``>(``element else "null"``)";
}
test
shared void serializeGeneric() {
    
    assertEquals(serialize(Generic("string")), """{"element":"string"}""");
    assertEquals(serialize(Generic(1)), """{"element":1}""");
    assertEquals(serialize(Generic(Generic("string"))), """{"element":{"element":"string"}}""");
    
    value generic = Generic("string");
    assertEquals(
        serialize { 
            rootInstance = generic of Object; 
            pretty = true; 
        }, 
        """{
            "class": "test.com.github.tombentley.alabama::Generic<ceylon.language::String>",
            "element": "string"
           }""");
        
        assertEquals(
            serialize { 
                rootInstance = generic; 
                pretty = true; 
            }, 
            """{
                "element": "string"
               }""");
}

abstract serializable class Payment(amount) {
    shared Float amount;
}
serializable class CreditCardPayment(Float amount, cardNumber) extends Payment(amount) {
    shared String cardNumber;
}
serializable class DebitCardPayment(Float amount, cardNumber) extends Payment(amount) {
    shared String cardNumber;
}

test
shared void serializePolymorphic() {
    Payment p = CreditCardPayment(0.99, "1234 5678 1234 5678");
    assertEquals(
        serialize { rootInstance = p; pretty = true; },
        """{
            "class": "test.com.github.tombentley.alabama::CreditCardPayment",
            "amount": 0.99,
            "cardNumber": "1234 5678 1234 5678"
           }""");
}


// TODO test ser, deser with polymorphism
// TODO test ser, deser with a tuple typed-attribute
// TODO test ser, deser with a tuple at toplevel
// TODO test ser, deser with enumerated types
// TODO support and test "type inference" with enumerated types
// TODO support ser, deser with wrapper objects and arrays

"""Example of entities in "Ceylon style", using named constructor arguments"""
serializable class Invoice(bill, deliver, items) {
    shared Person bill;
    shared Person deliver;
    shared [Item+] items;
    shared actual String string => "invoice to: ``bill``
                                    deliver to: ``deliver``
                                    items: ``"\n".join(items)``";
}

serializable class Person(name, address) {
    shared String name;
    shared Address address;
    shared actual String string => "``name``
                                    ``address``";
}

serializable class Address(lines, postCode) {
    shared String[] lines;
    shared String postCode;
    shared actual String string => ",\n".join(lines) + postCode;
}
serializable class Item(product, quantity) {
    shared Product product;
    shared Float quantity;
    shared actual String string => "``product.sku``\t``product.description else ""`` @ £``product.unitPrice`` x ``quantity``";
}

serializable class Product(sku, description, unitPrice, salesTaxRate) {
    shared String sku;
    shared String? description;
    shared Float unitPrice;
    shared Float salesTaxRate;
    
}

Invoice exampleInvoice => Invoice {
    bill = Person {
        name = "Mr Pig";
        address = Address {
            lines = ["3 Pigs House", "The Farm"];
            postCode = "3PH";
        };
    };
    deliver = Person {
        name = "Mr Pig";
        address = Address {
            lines = ["3 Pigs House", "The Farm"];
            postCode = "3PH";
        };
    };
    items = [
    Item {
        product = Product {
            sku="123";
            description = "Bag of sand";
            unitPrice = 2.34;
            salesTaxRate = 0.2;
        };
        quantity = 4.0;
    },
    Item {
        product = Product {
            sku="876";
            description = "Bag of cement";
            unitPrice = 3.57;
            salesTaxRate = 0.2;
        };
        quantity = 1.0;
    }
    ];
};

test 
shared void s11nSerialize() {
    assertEquals{actual= serialize(exampleInvoice, true);
        expected =  """{
                        "bill": {
                         "name": "Mr Pig",
                         "address": {
                          "lines": [
                           "3 Pigs House",
                           "The Farm"
                          ],
                          "postCode": "3PH"
                         }
                        },
                        "deliver": {
                         "name": "Mr Pig",
                         "address": {
                          "lines": [
                           "3 Pigs House",
                           "The Farm"
                          ],
                          "postCode": "3PH"
                         }
                        },
                        "items": [
                         {
                          "product": {
                           "sku": "123",
                           "description": "Bag of sand",
                           "unitPrice": 2.34,
                           "salesTaxRate": 0.2
                          },
                          "quantity": 4.0
                         },
                         {
                          "product": {
                           "sku": "876",
                           "description": "Bag of cement",
                           "unitPrice": 3.57,
                           "salesTaxRate": 0.2
                          },
                          "quantity": 1.0
                         }
                        ]
                       }""";
    };
}

abstract serializable class AttributeCollision(collides) {
    String collides;
    shared actual String string => collides;
}
serializable class CollisionSub(collides, String sup) extends AttributeCollision(sup) {
    shared Integer collides;
}
serializable class RenamedCollisionSub(collides, String sup) extends AttributeCollision(sup) {
    key("foo")
    shared Integer collides;
}

test 
shared void serializeCollidingAttribute() {
    // TODO when not renamed, do I care?
    assertEquals(serialize(CollisionSub(42, "super"), true),
        """{
            "collides": "super",
            "collides": 42
           }""");
    
    assertEquals(serialize(RenamedCollisionSub(42, "super"), true),
        """{
            "collides": "super",
            "foo": 42
           }""");
    // TODO need to test deserialization too
}

serializable class CyclicVariable() {
    shared variable Anything ref = null;
}
test
shared void serCyclicVariable() {
    CyclicVariable l = CyclicVariable();
    l.ref = l;
    assertEquals(serialize(l, true),
        """{
            "#": 1,
            "@ref": 1
           }""");
}

serializable class CyclicLate() {
    shared late Anything ref;
}
test
shared void serCyclicLate() {
    CyclicLate l = CyclicLate();
    l.ref = l;
    assertEquals(serialize(l, true),
        """{
            "#": 1,
            "@ref": 1
           }""");
}

test
shared void rtCyclicArray() {
    Array<Anything> l = Array<Anything>.ofSize(1, null);
    l.set(0, l);
    value json = serialize(l, true);
    assertEquals(json, """{"#":1,"value":[{"@":1}]""");
    
    value y = deserialize<Anything>(json);
    print(type(y));
    assert(is Array<Anything> a = y);
    assert(is Identifiable x=a[0], x === l); 
}


test
shared void serEmpty() {
    assertEquals(serialize([], true),
        """{
            "class": "ceylon.language::empty"
           }""");
    assertEquals(serialize(Generic([]), true),
        """{
            "element": {
             "class": "ceylon.language::empty"
            }
           }""" );
}

test
shared void rtTuple() {
    value tuple1 = [1, "2", true];
    variable value json = serialize(tuple1, false);
    assertEquals(json, """[1,"2",true]""");
    assertEquals {
        actual = deserialize<[Integer, String, Boolean]>(json);  
        expected = tuple1; 
    };
    
    json = serialize([Generic("S")], false);
    assertEquals(json, """[{"element":"S"}]""");
    assertEquals { 
        actual = deserialize<[Generic<String>]>(json)[0].element; 
        expected = "S"; 
    };
    
    json = serialize(Generic(tuple1), false);
    assertEquals(json, """{"element":[1,"2",true]}""");
    assertEquals { 
        actual = deserialize<Generic<[Integer, String, Boolean]>>(json).element; 
        expected = tuple1;
    };
    
    // TODO support tuple type abbrevs
    // tests where the deserializer doesn't know the expected type
    json = serialize<Object>(tuple1, false);
    assertEquals(json, """{"class":"ceylon.language::Tuple<ceylon.language::true|ceylon.language::String|ceylon.language::Integer,ceylon.language::Integer,ceylon.language::Tuple<ceylon.language::true|ceylon.language::String,ceylon.language::String,ceylon.language::Tuple<ceylon.language::true,ceylon.language::true,ceylon.language::empty>>>","value":[1,"2",true]}""");
    assertEquals { 
        actual = deserialize<Object>(json); 
        expected = tuple1; 
    };
    
    json = serialize<Object>([Generic("S")], false);
    assertEquals(json, """{"class":"ceylon.language::Tuple<test.com.github.tombentley.alabama::Generic<ceylon.language::String>,test.com.github.tombentley.alabama::Generic<ceylon.language::String>,ceylon.language::empty>","value":[{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::String>","element":"S"}]}""");
    assert(is [Generic<String>] got = deserialize<Object>(json));
    assertEquals { 
        actual = got[0].element; 
        expected = "S"; 
    };
    
    json = serialize<Object>(Generic(tuple1), false);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Tuple<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean,ceylon.language::Integer,ceylon.language::Tuple<ceylon.language::String|ceylon.language::Boolean,ceylon.language::String,ceylon.language::Tuple<ceylon.language::Boolean,ceylon.language::Boolean,ceylon.language::Empty>>>>","element":[1,"2",true]}""");
    assert(is Generic<[Integer, String, Boolean]> got2 = deserialize<Object>(json));
    assertEquals { 
        actual = got2.element; 
        expected = tuple1; 
    };
}
test
shared void rtTupleWithRest() {
    value tuple = [1, "2", true, *(4..6)];
    variable value json = serialize(tuple, true);
    assertEquals{
        expected = """[
                       1,
                       "2",
                       true,
                       4,
                       5,
                       6
                      ]""";
        actual = json;
    };
    value got1 = deserialize<[Integer|String|Boolean*]>(json);
    assertEquals{
        expected = tuple;
        actual = got1;
    };
    
    // TODO In this case all I actually need to know from the wrapper class
    // is that the JSON array is a Tuple (I don't need the tuple instantiation)
    // because the reification of tuple uses the runtime types
    json = serialize(tuple of Object, true);
    assertEquals{
        expected = """{
                       "class": "ceylon.language::Tuple<ceylon.language::Integer|ceylon.language::String|ceylon.language::true,ceylon.language::Integer,ceylon.language::Tuple<ceylon.language::Integer|ceylon.language::String|ceylon.language::true,ceylon.language::String,ceylon.language::Tuple<ceylon.language::Integer|ceylon.language::true,ceylon.language::true,ceylon.language::Span<ceylon.language::Integer>>>>",
                       "value": [
                        1,
                        "2",
                        true,
                        4,
                        5,
                        6
                       ]
                      }""";
        actual = json;
    };
    value got2 = deserialize<Object>(json);
    assertEquals{
        expected = tuple;
        actual = got2;
    };
    
}

test
shared void serArray() {
    assertEquals(serialize(Array{1, "2", true}, false), """[1,"2",true]""");
    assertEquals(serialize(Generic(Array{1, "2", true}), false), """{"element":[1,"2",true]}""");
    // in the following case we lose the fact that the top level object in an array
    assertEquals(serialize<Object>(Array{1, "2", true}, true), 
        """{
            "class": "ceylon.language::Array<ceylon.language::Integer|ceylon.language::String|ceylon.language::Boolean>",
            "value": [
             1,
             "2",
             true
            ]
           }""");
}

test
shared void rtArraySequence() {
    assert(is ArraySequence<Anything> as = (Array{1, "2", true}.sequence() of Object));
    variable value json = serialize(as);
    assertEquals(json, """[1,"2",true]""");
    assert(is ArraySequence<Anything> as2 = deserialize<Anything>(json));
    assert(as2 == as);
    
    json = serialize(Generic(as));
    assertEquals(json, """{"element":[1,"2",true]}""");
    value as3 = deserialize<Generic<ArraySequence<Anything>>>(json);
    assert(as3.element == as);
}

test
shared void serMeasure() {
    // this representation is not wrong, but not great either
    // note we always get the "class" key because the static type
    // is Range (because Measure is not visible), which is not specific enough
    assertEquals(serialize(measure(0, 3), true),
        """{
            "class": "ceylon.language::Measure<ceylon.language::Integer>",
            "first": 0,
            "size": 3
           }""");
    assertEquals(serialize(Generic(measure(0, 3)), true), 
        """{
            "element": {
             "class": "ceylon.language::Measure<ceylon.language::Integer>",
             "first": 0,
             "size": 3
            }
           }""");
    
    assertEquals(serialize<Object>(measure(0, 3), true),
        """{
            "class": "ceylon.language::Measure<ceylon.language::Integer>",
            "first": 0,
            "size": 3
           }""");
    //assertEquals(serialize(Generic<Object>(measure(0, 3))), """{"element":[0,1,2]}""");
}

test
shared void serSpan() {
    // this representation is not wrong, but not great either
    // note we always get the "class" key because the static type
    // is Range (because Span is not visible), which is not specific enough
    assertEquals(serialize(span(0, 3), true), 
        """{
            "class": "ceylon.language::Span<ceylon.language::Integer>",
            "first": 0,
            "last": 3,
            "recursive": false,
            "increasing": true
           }""");
    assertEquals(serialize(Generic(span(0, 3)), true), 
        """{
            "element": {
             "class": "ceylon.language::Span<ceylon.language::Integer>",
             "first": 0,
             "last": 3,
             "recursive": false,
             "increasing": true
            }
           }""");
}

// TODO a non-serializable class
// TODO getting the right type info for attributes, and elements

test
shared void rtString() {
    variable String json = serialize("hello, world");
    assertEquals(json, """"hello, world"""");
    assertEquals(deserialize<String>(json), "hello, world");
    
    json = serialize("hello, world" of Object);
    assertEquals(json, """"hello, world"""");
    assertEquals(deserialize<Object>(json), "hello, world");
    
    json = serialize("hello, world" of String?);
    assertEquals(json, """"hello, world"""");
    assertEquals(deserialize<String?>(json), "hello, world");
}

test
shared void rtInteger() {
    variable String json = serialize(42);
    assertEquals(json, """42""");
    assertEquals(deserialize<Integer>(json), 42);
    
    json = serialize(42 of Object);
    assertEquals(json, """42""");
    assertEquals(deserialize<Object>(json), 42);
}

test
shared void rtFloat() {
    variable String json = serialize(42.5);
    assertEquals(json, """42.5""");
    assertEquals(deserialize<Float>(json), 42.5);
    
    json = serialize(42.5 of Object);
    assertEquals(json, """42.5""");
    assertEquals(deserialize<Object>(json), 42.5);
}

test
shared void rtMinusZero() {
    variable String json = serialize(-0.0);
    assertEquals(json, """-0.0""");
    value got = deserialize<Float>(json);
    assertEquals(got, -0.0);
    assertTrue(got.strictlyNegative);
    
}

test
shared void rtNaN() {
    variable String json = serialize(0.0/0.0);
    assertEquals(json, """{"value":"NaN"}""");
    assertTrue(deserialize<Float>(json).undefined);
    
    json = serialize<Object>(0.0/0.0);
    assertEquals(json, """{"class":"ceylon.language::Float","value":"NaN"}""");
    assertTrue(deserialize<Float>(json).undefined);
}

test
shared void rtInfinity() {
    value infinity = 1.0/0.0;
    variable String json = serialize(infinity);
    assertEquals(json, """{"value":"∞"}""");
    assertEquals(deserialize<Float>(json), infinity);
    
    json = serialize<Object>(infinity);
    assertEquals(json, """{"class":"ceylon.language::Float","value":"∞"}""");
    assertEquals(deserialize<Float>(json), infinity);
    
    json = serialize(-infinity);
    assertEquals(json, """{"value":"-∞"}""");
    assertEquals(deserialize<Float>(json), -infinity);
    
    json = serialize<Object>(-infinity);
    assertEquals(json, """{"class":"ceylon.language::Float","value":"-∞"}""");
    assertEquals(deserialize<Float>(json), -infinity);
    
    json = serialize([infinity]);
    assertEquals(json, """[{"value":"∞"}]""");
    assertEquals(deserialize<[Float]>(json), [infinity]);
    
    json = serialize<Object>([infinity]);
    assertEquals(json, """{"class":"ceylon.language::Tuple<ceylon.language::Float,ceylon.language::Float,ceylon.language::empty>","value":[{"class":"ceylon.language::Float","value":"∞"}]}""");
    assertEquals(deserialize<Object>(json), [infinity]);
    
}

test
shared void rtBoolean() {
    variable String json = serialize(true);
    assertEquals(json, """true""");
    assertEquals(deserialize<Boolean>(json), true);
    
    json = serialize(true of Object);
    assertEquals(json, """true""");
    assertEquals(deserialize<Object>(json), true);
}

test
shared void rtNull() {
    variable String json = serialize(null);
    assertEquals(json, """null""");
    assertEquals(deserialize<Anything>(json), null);
    
    json = serialize(null of String?);
    assertEquals(json, """null""");
    assertEquals(deserialize<String?>(json), null);
}

test
shared void rtCharacter() {
    variable String json = serialize('x');
    assertEquals(json, """"x"""");
    assertEquals(deserialize<Character>(json), 'x');
    
    json = serialize<Object>('x' of Object);
    assertEquals(json, """{"class":"ceylon.language::Character","value":"x"}""");
    assertEquals(deserialize<Object>(json), 'x');
}


test
shared void rtEmpty() {
    variable String json = serialize([]);
    assertEquals(json, """{"class":"ceylon.language::empty"}""");
    assertEquals(deserialize<[]>(json), []);
    
    json = serialize<Object>([]);
    assertEquals(json, """{"class":"ceylon.language::empty"}""");
    assertEquals(deserialize<Object>(json), []);
}

test
shared void rtLarger() {
    variable String json = serialize(larger);
    assertEquals(json, """{"class":"ceylon.language::larger"}""");
    assertEquals(deserialize<\Ilarger>(json), larger);
    assertEquals(deserialize<Comparison>(json), larger);
    
    json = serialize(larger of Object);
    assertEquals(json, """{"class":"ceylon.language::larger"}""");
    assertEquals(deserialize<Object>(json), larger);
}

serializable class StringContainer(string) {
    shared actual String string;
}

test
shared void rtStringContainer() {
    variable String json = serialize(StringContainer("hello, world"));
    assertEquals(json, """{"string":"hello, world"}""");
    assertEquals(deserialize<StringContainer>(json).string, "hello, world");
    
    json = serialize(StringContainer("hello, world") of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::StringContainer","string":"hello, world"}""");
    assertEquals(deserialize<Object>(json).string, "hello, world");
}

test
shared void rtGenericString() {
    variable String json = serialize(Generic("hello, world"));
    assertEquals(json, """{"element":"hello, world"}""");
    assertEquals(deserialize<Generic<String>>(json).element, "hello, world");
    
    json = serialize(Generic("hello, world") of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::String>","element":"hello, world"}""");
    assert(is Generic<String> o = deserialize<Object>(json));
    assertEquals(o.element, "hello, world");
}

test
shared void rtGenericOptionalString() {
    variable String json = serialize(Generic<String?>("hello, world"));
    assertEquals(json, """{"element":"hello, world"}""");
    assertEquals(deserialize<Generic<String?>>(json).element, "hello, world");
    
    json = serialize(Generic<String?>(null));
    assertEquals(json, """{"element":null}""");
    assertEquals(deserialize<Generic<String?>>(json).element, null);
    
    json = serialize(Generic<String?>("hello, world") of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Null|ceylon.language::String>","element":"hello, world"}""");
    assert(is Generic<String?> o = deserialize<Object>(json));
    assertEquals(o.element, "hello, world");
    
    json = serialize(Generic<String?>(null) of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Null|ceylon.language::String>","element":null}""");
    assert(is Generic<String?> o2 = deserialize<Object>(json));
    assertEquals(o2.element, null);
}

test
shared void rtGenericCharacter() {
    variable String json = serialize(Generic('x'));
    assertEquals(json, """{"element":"x"}""");
    assertEquals(deserialize<Generic<Character>>(json).element, 'x');
    
    json = serialize(Generic('x') of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Character>","element":"x"}""");
    assert(is Generic<Character> o = deserialize<Object>(json));
    assertEquals(o.element, 'x');
}

test
shared void rtGenericEmpty() {
    variable String json = serialize(Generic([] of String[]));
    assertEquals(json, """{"element":{"class":"ceylon.language::empty"}}""");
    assertEquals(deserialize<Generic<String[]>>(json).element, []);
    
    json = serialize(Generic([] of String[]) of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Sequential<ceylon.language::String>>","element":{"class":"ceylon.language::empty"}}""");
    assert(is Generic<String[]> o = deserialize<Object>(json));
    assertEquals(o.element, []);
}

test
shared void rtGenericLarger() {
    variable String json = serialize(Generic(larger));
    assertEquals(json, """{"element":{"class":"ceylon.language::larger"}}""");
    assertEquals(deserialize<Generic<Comparison>>(json).element, larger);
    
    json = serialize(Generic(larger) of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Generic<ceylon.language::Comparison>","element":{"class":"ceylon.language::larger"}}""");
    assert(is Generic<Comparison> o = deserialize<Object>(json));
    assertEquals(o.element, larger);
}

serializable class Late() {
    shared late String required;
    shared late String? nullable;
}
"tests we can serialize and deserialize objects with uninitialized late attributes"
test
shared void rtLate() {
    variable String json = serialize(Late() of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::Late"}""");
    variable Late r = deserialize<Late>(json);
    r.required = "";
    r.nullable = null;
    
    Late l = Late();
    l.required = "req";
    l.nullable = "nul";
    json = serialize(l, true);
    assertEquals(json,
        """{
            "required": "req",
            "nullable": "nul"
           }""");
    r = deserialize<Late>(json);
    assertEquals(r.required, "req");
    assertEquals(r.nullable, "nul");
}

serializable class LateVariable() {
    shared variable late String required;
    shared variable late String? nullable;
}
"tests we can serialize and deserialize objects with uninitialized late variableattributes"
test
shared void rtLateVariable() {
    variable String json = serialize(LateVariable() of Object);
    assertEquals(json, """{"class":"test.com.github.tombentley.alabama::LateVariable"}""");
    variable LateVariable r = deserialize<LateVariable>(json);
    r.required = "";
    r.nullable = null;
    
    LateVariable l = LateVariable();
    l.required = "req";
    l.nullable = "nul";
    json = serialize(l, true);
    assertEquals(json,
        """{
            "required": "req",
            "nullable": "nul"
           }""");
    r = deserialize<LateVariable>(json);
    assertEquals(r.required, "req");
    assertEquals(r.nullable, "nul");
}

test
shared void rtSingleton() {
    variable value json = serialize(Singleton('x'));
    assertEquals(json, """["x"]""");
    assertEquals(deserialize<Singleton<Character>>(json), Singleton('x'));
    
    json = serialize(Singleton('x' of Object));
    assertEquals(json, """[{"class":"ceylon.language::Character","value":"x"}]""");
    // Need to know it's supposed to be a singleton, otherwise we just get ArraySequence
    assertEquals(deserialize<Singleton<Anything>>(json), Singleton('x'));
    assertEquals(deserialize<Object>(json), Singleton('x'));
    
    json = serialize(Generic<Object>(Singleton('x')));
    print(json);
    //assertEquals(json, """{"element":[{"class":"ceylon.language::Character","character":"x"}]}""");
    
    json = serialize<Object>(Generic(Singleton('x')));
    print(json);
    //assertEquals(json, """{"element":[{"class":"ceylon.language::Character","character":"x"}]}""");
}

serializable class Zero() {
    shared actual Boolean equals(Object other) {
        return other is Zero;
    }
}
serializable class One(first) {
    Anything first;
    shared actual Boolean equals(Object other) {
        if (is One other) {
            if (is Object first, is Object f=other.first) {
                return first == f;
            } else if (!first is Object ) {
                return !other.first is Object; 
            } else {
                return false; 
            }
        } else {
            return false;
        }
    }
}
serializable class Two(left, right) {
    Anything left;
    Anything right;
    shared actual Boolean equals(Object other) {
        if (is Two other) {
            variable Boolean same;
            if (exists left) {
                same = other.left is Object;
            } else {
                same = !other.left is Object;
            }
            if (same) {
                if (exists right) {
                    same = other.right is Object;
                } else {
                    same = !other.right is Object;
                }
            }
            return same;
        } else {
            return false;
        }
    }
}
test
shared void rtDiamond() {
    Zero zero = Zero();
    One left = One(zero);
    One right = One(zero);
    Two top = Two(left, right);
    variable value json = serialize(top, true);
    assertEquals(json, """{
                           "left": {
                            "class": "test.com.github.tombentley.alabama::One",
                            "first": {
                             "class": "test.com.github.tombentley.alabama::Zero",
                             "#": 1
                            }
                           },
                           "right": {
                            "class": "test.com.github.tombentley.alabama::One",
                            "@first": 1
                           }
                          }""");
}

