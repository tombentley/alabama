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
    TypeExpressionTypeNaming
}
shared void profileSer() {
    value serializer = Serializer {
        
    };
    
    variable value times = 2000;
    variable value hs = 0;
    variable String json="";
    print("warmup: serializing exampleInvoice ``times`` times");
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
    
    times = 30_000;
    print("warmup complete. attach your profiler");
    while(true) {
        print("press enter to start timing run of ``times`` serializations");
        process.readLine();
        
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
}
shared void profileDeser() {
    variable value times = 2_000;
    variable value hs = 0;
    variable String json=exampleJson;
    print("warmup: deserializing exampleJson ``times`` times");
    value deserializer = Deserializer(`Invoice`, TypeExpressionTypeNaming(), "class");
    for (i in 1..times) {
        Invoice invoice = deserializer.deserialize(StreamParser(StringTokenizer(json)));
        if (i == 1) {
            print(invoice);
        }
        hs+=invoice.hash;
    }
    print("warmup complete. attach your profiler");
    times = 16_000;
    while(true) {
        print("press enter to start timing run of ``times`` deserializations");
        process.readLine();
        
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
}