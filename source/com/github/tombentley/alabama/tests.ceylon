import ceylon.test {
    test,
    assertEquals,
    fail
}
import ceylon.language.meta.declaration {
    ValueDeclaration
}

""" Example using "JavaBean style" will a nullary class parameter list and `late` attributes.""" 
class LateInvoice() {
    shared late LatePerson bill;
    shared late LatePerson deliver;
    shared late [LateItem+] items;
    shared actual String string => "bill: ``bill``.
                                    deliver to: ``deliver``.
                                    ``items``
                                    ";
}
class LatePerson() {
    shared late String name;
    shared late LateAddress address;
    shared actual String string => "``name```,
                                    ``address``";
}
class LateAddress() {
    shared late String[] lines;
    shared late String postCode;
    shared actual String string => "``lines```,
                                    ``postCode``";
}
class LateItem() {
    shared late LateProduct product;
    shared late Float quantity;
    shared actual String string => "``product```\t``quantity``";
}
class LateProduct() {
    shared late String sku;
    shared late String description;
    shared late Float unitPrice;
    shared late Float salesTaxRate;
    shared actual String string => "``sku```\t``description``\t``unitPrice``\t``salesTaxRate``";
}

LateInvoice exampleLate {
    value bagOfSand = LateProduct();
    bagOfSand.sku = "123";
    bagOfSand.description = "Bag of sand";
    bagOfSand.unitPrice = 2.34;
    bagOfSand.salesTaxRate = 0.2;
    value fourBagsOfSand = LateItem();
    fourBagsOfSand.product = bagOfSand;
    fourBagsOfSand.quantity = 4.0;
    value bagOfCement = LateProduct();
    bagOfCement.sku = "876";
    bagOfCement.description = "Bag of cement";
    bagOfCement.unitPrice = 3.57;
    bagOfCement.salesTaxRate = 0.2;
    value oneBagOfCement = LateItem();
    oneBagOfCement.product = bagOfCement;
    oneBagOfCement.quantity = 1.0;
    
    value mrPig = LatePerson();
    mrPig.name = "Mr Pig";
    mrPig.address = LateAddress();
    mrPig.address.lines = ["3 Pigs House", "The Farm"];
    mrPig.address.postCode = "3PH";
    value invoice = LateInvoice();
    invoice.deliver = mrPig;
    invoice.bill = mrPig;
    invoice.items = [fourBagsOfSand, oneBagOfCement];
    
    return invoice;
}


"""Example using "JavaBean style" with variable nullable attributes."""
class NullInvoice() {
    shared variable NullPerson? bill = null;
    shared variable NullPerson? deliver = null;
    shared variable [NullItem+]? items = null;
    shared actual String string => "bill: ``bill else "null"``.
                                    deliver to: ``deliver else "null"``.
                                    ``items else "null"``
                                    ";
}
class NullPerson() {
    shared variable String? name = null;
    shared variable NullAddress? address = null;
    shared actual String string => "``name else "null"``,
                                    ``address else "null"``";
}
class NullAddress() {
    shared variable String[] lines = [];
    shared variable String? postCode = null;
    shared actual String string => "``lines``,
                                    ``postCode else "null"``";
}
class NullItem() {
    shared variable NullProduct? product = null;
    shared variable Float? quantity = null;
    shared actual String string => "``product else "null"```\t``quantity else "null"``";
}
class NullProduct() {
    shared variable String? sku = null;
    shared variable String? description = null;
    shared variable Float? unitPrice = null;
    shared variable Float? salesTaxRate = null;
    shared actual String string => "``sku else "null"```\t``description else "null"``\t``unitPrice else "null"``\t``salesTaxRate else "null"``";
}

NullInvoice exampleNull {
    value bagOfSand = NullProduct();
    bagOfSand.sku = "123";
    bagOfSand.description = "Bag of sand";
    bagOfSand.unitPrice = 2.34;
    bagOfSand.salesTaxRate = 0.2;
    value fourBagsOfSand = NullItem();
    fourBagsOfSand.product = bagOfSand;
    fourBagsOfSand.quantity = 4.0;
    value bagOfCement = NullProduct();
    bagOfCement.sku = "876";
    bagOfCement.description = "Bag of cement";
    bagOfCement.unitPrice = 3.57;
    bagOfCement.salesTaxRate = 0.2;
    value oneBagOfCement = NullItem();
    oneBagOfCement.product = bagOfCement;
    oneBagOfCement.quantity = 1.0;
    
    value mrPig = NullPerson();
    mrPig.name = "Mr Pig";
    value mrPigAddress = NullAddress();
    mrPigAddress.lines = ["3 Pigs House", "The Farm"];
    mrPigAddress.postCode = "3PH";
    mrPig.address = mrPigAddress;
    value invoice = NullInvoice();
    invoice.deliver = mrPig;
    invoice.bill = mrPig;
    invoice.items = [fourBagsOfSand, oneBagOfCement];
    
    return invoice;
}



"""Example of entities in "Ceylon style", using named constructor arguments"""
class Invoice(bill, deliver, items) {
    shared Person bill;
    shared Person deliver;
    shared [Item+] items;
}
class Person(name, address) {
    shared String name;
    shared Address address;
}
class Address(lines, postCode) {
    shared String[] lines;
    shared String postCode;
}
class Item(product, quantity) {
    shared Product product;
    shared Float quantity;
}
class Product(sku, description, unitPrice, salesTaxRate) {
    shared String sku;
    shared String? description;
    shared Float unitPrice;
    shared Float salesTaxRate;
}

Invoice example => Invoice {
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
shared void serializeInvoice() {
    assertEquals("""{
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
                    }""", 
    serialize(example, true));
}
test
shared void serializeNullInvoice() {
    assertEquals(serialize(exampleNull, true),
                 """{
                     "bill": {
                      "address": {
                       "postCode": "3PH",
                       "lines": [
                        "3 Pigs House",
                        "The Farm"
                       ]
                      },
                      "name": "Mr Pig"
                     },
                     "items": [
                      {
                       "product": {
                        "salesTaxRate": 0.2,
                        "description": "Bag of sand",
                        "unitPrice": 2.34,
                        "sku": "123"
                       },
                       "quantity": 4.0
                      },
                      {
                       "product": {
                        "salesTaxRate": 0.2,
                        "description": "Bag of cement",
                        "unitPrice": 3.57,
                        "sku": "876"
                       },
                       "quantity": 1.0
                      }
                     ],
                     "deliver": {
                      "address": {
                       "postCode": "3PH",
                       "lines": [
                        "3 Pigs House",
                        "The Farm"
                       ]
                      },
                      "name": "Mr Pig"
                     }
                    }""");
}
test
shared void serializeLateInvoice() {
    assertEquals(serialize(exampleLate, true),
                 """{
                     "bill": {
                      "address": {
                       "postCode": "3PH",
                       "lines": [
                        "3 Pigs House",
                        "The Farm"
                       ]
                      },
                      "name": "Mr Pig"
                     },
                     "deliver": {
                      "address": {
                       "postCode": "3PH",
                       "lines": [
                        "3 Pigs House",
                        "The Farm"
                       ]
                      },
                      "name": "Mr Pig"
                     },
                     "items": [
                      {
                       "product": {
                        "salesTaxRate": 0.2,
                        "description": "Bag of sand",
                        "unitPrice": 2.34,
                        "sku": "123"
                       },
                       "quantity": 4.0
                      },
                      {
                       "product": {
                        "salesTaxRate": 0.2,
                        "description": "Bag of cement",
                        "unitPrice": 3.57,
                        "sku": "876"
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
                                "sku": "123",
                                "description": "",
                                "unitPrice": 3.45,
                                "salesTaxRate": 0.2
                              },
                              "quantity": 1.0
                            },
                            {
                              "product": {
                                "sku": "123",
                                "description": "",
                                "unitPrice": 3.45,
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
    variable value cs = readClass(`class AnnotationsExample`, namedParameterMemberizer);
    assert(`class AnnotationsExample` == cs.clazz);
    assert(["gee"] == cs.ignoredKeys);
    assert(`value AnnotationsExample.baz` in cs.omittedAttributes);
    assert(exists b= cs.keys["foo"]);
    assert(exists b2= cs.keys["fooble"]);
    assert(b===b2);
    assert(b.attr == `value AnnotationsExample.bar`);
    assert(b.key == "foo");
    
    try {
        cs = readClass(`class AnnotationsExample2`, namedParameterMemberizer);
        fail("excepted exception");
    } catch (AssertionError e) {
        assertEquals(e.message, """ignored keys cannot also be keys: foo""");
    }
    try {
        cs = readClass(`class AnnotationsExample3`, namedParameterMemberizer);
        fail("excepted exception");
    } catch (AssertionError e) {
        assertEquals(e.message, "ignored keys cannot also be keys: foo");
    }
    
    cs = readClass(`class AnnotationsExample4`, namedParameterMemberizer);
    assert(exists b3= cs.keys["bar"]);
    assert(exists b4= cs.keys["fooble"]);
    assert(b3===b4);
    assert(b3.attr == `value AnnotationsExample4.bar`);
    assert(b3.key == "bar");
    
    cs = readClass(`class AnnotationsExample5`, namedParameterMemberizer);
    cs = readClass(`class AnnotationsExample6`, namedParameterMemberizer);
}

class Generic<Element>(element) {
    shared Element element;
}
test
shared void generic() {
    // TODO 
    print(serialize(Generic("string")));
    print(serialize(Generic(1)));
    print(serialize(Generic(Generic("string"))));
}

abstract class Payment(amount) {
    shared Float amount;
}
class CreditCardPayment(Float amount, cardNumber) extends Payment(amount) {
    shared String cardNumber;
}
class DebitCardPayment(Float amount, cardNumber) extends Payment(amount) {
    shared String cardNumber;
}

test
shared void poly1() {
    print(serialize(CreditCardPayment(0.99, "1234 5678 1234 5678")));
}

class NullaryConstructor {
    shared new () {
        assert(false);
    }
    new WrongConstructor() {
        assert(false);
    }
    deserialization
    new Constructor() {}
}

// TODO test ser, deser with nallary constructor
// TODO test ser, deser annotated constructor
// TODO test ser, deser with polymorphism
// TODO test ser, deser with the JSON types
// TODO test ser, deser with a tuple typed-attribute
// TODO test ser, deser with a tuple at toplevel
// TODO test ser, deser with enumerated types
// TODO support and test "type inference" with enumerated types
// TODO support ser, deser with wrapper objects and arrays