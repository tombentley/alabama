import ceylon.language.meta {
    typeLiteral
}
import ceylon.test {
    test,
    assertEquals,
    fail
}

import com.github.tombentley.alabama {
    Config,
    omittedAttribute,
    serialize,
    aliasedKey,
    key,
    ignoredKeys
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

