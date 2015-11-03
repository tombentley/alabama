import ceylon.json {
    StringEmitter,
    StringTokenizer
}
import ceylon.json.stream {
    StreamParser
}
import com.github.tombentley.alabama {
    Serializer,
    Deserializer,
    fqTypeNaming
}
shared void profileSer() {
    value serializer = Serializer {
        
    };
    variable value times = 2000;
    variable value hs = 0;
    variable String json="";
    for (i in 1..times) {
        value visitor = StringEmitter();
        serializer.serialize(visitor, exampleInvoice);
        value x = visitor.string;
        if (i == 1) {
            json = x;
            print(x);
        }
        hs+=x.hash; 
    }
    
    print("press enter");
    process.readLine();
    
    times = 10_000;
    variable value t0 = system.nanoseconds;
    for (i in 1..times) {
        value visitor = StringEmitter();
        serializer.serialize(visitor, exampleInvoice);
        value x = visitor.string;
        if (i == 1) {
            print(x);
        }
        hs+=x.hash; 
    }
    
    variable value elapsed = (system.nanoseconds - t0)/1_000_000.0;
    print("``elapsed``ms total");
    print("``elapsed/times``ms per serialization");
    print(hs);
    
}
shared void profileDeser() {
    variable value times = 2000;
    variable value hs = 0;
    variable String json=exampleJson;
    value deserializer = Deserializer(`Invoice`, fqTypeNaming, "class");
    for (i in 1..times) {
        Invoice invoice = deserializer.deserialize(StreamParser(StringTokenizer(json)));
        if (i == 1) {
            print(invoice);
        }
        hs+=invoice.hash;
    }
    
    print("press enter");
    process.readLine();
    
    
    times = 8000;
    
    
    value t0 = system.nanoseconds;
    for (i in 1..times) {
        Invoice invoice = deserializer.deserialize(StreamParser(StringTokenizer(json)));
        if (i == 1) {
            print(invoice);
        }
    }
    value elapsed  = (system.nanoseconds - t0)/1_000_000.0;
    print("``elapsed``ms total");
    print("``elapsed/times``ms per deserialization");
}