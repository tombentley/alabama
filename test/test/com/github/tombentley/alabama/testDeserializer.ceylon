import com.github.tombentley.alabama {
    Deserializer,
    LogicalTypeNaming
}
import ceylon.json {
    StringTokenizer
}
import ceylon.json.stream {
    StreamParser
}
import ceylon.collection {
    HashMap
}
import ceylon.language.meta.model {
    Type
}
shared void run() {
    value deserializer = Deserializer {
        clazz = `Invoice`;
        parsers = map{`Type<>`->LogicalTypeNaming(HashMap{
            "Person" -> `Person3`,
            "Address" -> `Address3`,
            "Item" -> `Item`,
            "Product" -> `Product`,
            "Invoice" -> `Invoice`
        })};
        typeProperty = "class"; 
    };
    variable value times = 1000;
    variable value hs = 0;
    for (i in 1..times) {
        value x = deserializer.deserialize(StreamParser(StringTokenizer(exampleJson)));
        if (i == 1) {
            print(x);
        }
        hs+=x.hash; 
    }
    print("press enter");
    process.readLine();
    times = 4000;
    value t0 = system.nanoseconds;
    for (i in 1..times) {
        value x = deserializer.deserialize(StreamParser(StringTokenizer(exampleJson)));
        //print(x);
        hs+=x.hash; 
    }
    value elapsed = (system.nanoseconds - t0)/1_000_000.0;
    print("``elapsed``ms total");
    print("``elapsed/times``ms per deserialization");
    print(hs);
}

