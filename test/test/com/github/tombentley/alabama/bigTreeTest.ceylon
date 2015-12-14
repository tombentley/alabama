import ceylon.test {
    test
}
import com.github.tombentley.alabama {
    deserialize,
    serialize
}
serializable class Node(name, children) {
    shared Integer name;
    shared List<Node> children;
}

class BigTreeMaker(Integer nodes, Integer numChildren(Integer level, Integer childrenAtLevel)) {
    
    variable Integer n = 0;
    
    
    shared default List<Node> makeChildren({Node*} children) {
        return children.sequence();
    }

    shared default Node makeNode(Integer height, Integer numChildren) {
        n++;
        value children = [for (i in 0:numChildren) makeNode(height-1, this.numChildren(height-1, numChildren))];
        return Node(numChildren, makeChildren(children));
    }
    
    shared Node makeTree() {
        return makeNode(nodes, nodes);
    }
    
    shared Integer size => n;
}

test
shared void rtWideTree() {
    for (i in [2, 2, *(2..8)]) {// repeat 2 so as to warm JIT 
        value maker = BigTreeMaker(i, (height,x) => x-1);
        value a = maker.makeTree();
        // with static type info
        variable value t0 = system.nanoseconds;
        variable value json = serialize(a, true);
        variable value ms = (system.nanoseconds-t0)/1_000_000.0;
        print("Serializing a tree of ``maker.size`` nodes took ``ms``ms (``ms/maker.size``ms/node)");
        //print(json);
        //assertEquals(json, """[]""");
        t0 = system.nanoseconds;
        variable value a2 = deserialize<Node>(json);
        ms = (system.nanoseconds-t0)/1_000_000.0;
        print("Deserializing a tree of ``maker.size`` nodes took ``ms``ms (``ms/maker.size``ms/node)");
        print(a2);
    }
}

test
shared void rtTallTree() {
    //for (i in [2, 2, *(2..8)]) {
    Integer size = 800;// Any bigger and we SOE during serialization
    variable Node n = Node(0, []);
    for (i in 1..size) {
        n = Node(i, [n]);
    }
    
    //value maker = BigTreeMaker(i, (height,x) => height > 1_000 then 0 else 1);
    value a =n;// maker.makeTree();
    //print("Serializing a tree of ``bg.size`` nodes");
    // with static type info
    variable value t0 = system.nanoseconds;
    variable value json = serialize(a, true);
    variable value ms = (system.nanoseconds-t0)/1_000_000.0;
    print("Serializing a tree of ``size`` nodes took ``ms``ms (``ms/size``ms/node)");
    //print(json);
    //assertEquals(json, """[]""");
    t0 = system.nanoseconds;
    variable value a2 = deserialize<Node>(json);
    ms = (system.nanoseconds-t0)/1_000_000.0;
    print("Deserializing a tree of ``size`` nodes took ``ms``ms (``ms/size``ms/node)");
    print(a2);
    //assertEquals(a2.size, 0);
    //assert(! a2[0] exists);
    //}
}