import ceylon.test {
    test,
    assertEquals
}
import com.github.tombentley.alabama {
    serialize,
    deserialize
}
serializable class Person(first, last, address) {
    shared String first;
    shared String last;
    shared Address address;
}
serializable class Address(lines, zip) {
    [String+] lines;
    String zip;
}
serializable class TestClass(shared Integer|Float|[String*]|[Float+] a) {}

test
shared void canonicalExample() { 
    value p = Person {
        first = "Humpty";
        last = "Dumpty";
        address = Address {
            lines = ["Jackson", "Alabama"]; 
            zip = "1234";
        };
    };
    
    String json = serialize { 
        rootInstance = p; 
        pretty = true; 
    };
    Person p2 = deserialize<Person>(json);
    print(json);
}

test shared void itShouldSupportClassesWithUnionTypeAttributes() {
    assertEquals(deserialize<TestClass>(serialize(TestClass(2))).a, 2);
    assertEquals(deserialize<TestClass>(serialize(TestClass(["HELLO"]))).a, ["HELLO"]);
    assertEquals(deserialize<TestClass>(serialize(TestClass([1.4]))).a, [1.4]);
    assertEquals(deserialize<TestClass>(serialize(TestClass(1.4))).a, 1.4);
}

test shared void itShouldSupportUnionTypesWithSequences() {
    assertEquals(deserialize<Integer|[String*]|[Float+]>("""["HELLO"]"""), ["HELLO"]);
    assertEquals(deserialize<Integer|[String*]>("1"), 1);
    assertEquals(deserialize<Integer|[String*]|[Float+]>("""[1.4]"""), [1.4]);
}