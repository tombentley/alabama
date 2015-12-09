import ceylon.test {
    test
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