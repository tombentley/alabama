import com.github.tombentley.alabama {
    Serializer
}
import ceylon.json {
    StringEmitter
}

shared void runSer() {
    value serializer = Serializer {
        
    };
    variable value times = 2000;
    variable value hs = 0;
    for (i in 1..times) {
        value visitor = StringEmitter();
        serializer.serialize(visitor, exampleInvoice);
        value x = visitor.string;
        if (i == 1) {
            print(x);
        }
        hs+=x.hash; 
    }
    print("press enter");
    process.readLine();
    times = 8000;
    value t0 = system.nanoseconds;
    for (i in 1..times) {
        value visitor = StringEmitter();
        serializer.serialize(visitor, exampleInvoice);
        value x = visitor.string;
        if (i == 1) {
            print(x);
        }
        hs+=x.hash; 
    }
    value elapsed = (system.nanoseconds - t0)/1_000_000.0;
    print("``elapsed``ms total");
    print("``elapsed/times``ms per deserialization");
    print(hs);
}
