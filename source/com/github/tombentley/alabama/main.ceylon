import ceylon.collection{ArrayList,
    HashMap}
import ceylon.json {
    StringTokenizer
}
import ceylon.json.stream {
    StreamParser
}

Factura crear() {
  return Factura {
    numero=666;
    fecha=20150312;
    autor=Entidad{
      nombre="Red Hat, Inc.";
      rfc="RHI123456ABC";
      domicilio=Domicilio { 
          calle = "Calle"; 
          numExt = "1"; 
          numInt = "2"; 
          colonia = "Polanco"; 
          municipio = "Miguel Hidalgo"; 
          estado = "DF"; 
          cp = "11800"; 
          pais = "Mexico"; 
      };
    };
    destino=Entidad{
      nombre="Enrique Zamudio";
      rfc="EZL654321ABC";
      domicilio=Domicilio { 
          calle = "Amargura"; 
          numExt = "123"; 
          numInt = null; 
          colonia = "Del Carmen"; 
          municipio = "Coyoacan"; 
          estado = "DF"; 
          cp = "04100"; 
          pais = "Mexico"; 
      };
    };
    items=[
      Itemo { 
        producto = Producto { 
            nombre = "Soporte Anual"; 
            sku = "12341234"; 
            precio = 50.00; }; 
        cantidad = 1; },
      Itemo { 
          producto = Producto { 
              nombre = "Licencia RHEL"; 
              sku = "12341111"; 
              precio = 200.00; }; 
          cantidad = 2; },
      Itemo { 
          producto = Producto { 
              nombre = "Playeras"; 
              sku = "43214321"; 
              precio = 20.00; }; 
          cantidad = 1; }
    ];
  };
}

String jsonFactura = """{
                        "numero":666,
                        "fecha":20150312,
                        "autor": {
                          "nombre":"Red Hat, Inc.",
                          "rfc":"RHI123456ABC",
                          "domicilio": {
                            "calle":"Calle",
                            "numExt":"1",
                            "numInt":"2",
                            "colonia": "Polanco",
                            "municipio": "Miguel Hidalgo",
                            "estado":"DF",
                            "cp":"11800",
                            "pais":"Mexico"
                          }
                        },
                        "destino": {
                          "nombre":"Enrique Zamudio",
                          "rfc":"EZL6543221ABC",
                          "domicilio": {
                            "calle":"Amargura",
                            "numExt":"123",
                            "numInt":null,
                            "colonia": "Del Carmen",
                            "municipio": "Coyoacan",
                            "estado":"DF",
                            "cp":"04100",
                            "pais":"Mexico"
                          }
                        },
                        "items": [
                          {
                            "producto": {
                              "nombre": "Soporte Anual",
                              "sku": "12341234",
                              "precio": 50.00
                            },
                            "cantidad": 1
                          },
                          {
                            "producto": {
                              "nombre": "Licencia RHEL",
                              "sku": "12341111",
                              "precio": 200.00
                            },
                            "cantidad": 2
                          },
                          {
                            "producto": {
                              "nombre": "Playeras",
                              "sku": "43214321",
                              "precio": 20.00
                            },
                            "cantidad": 1
                          }
                        ]
                        }""";

class Stopwatch() {
    variable Integer t0 = system.nanoseconds;
    variable Integer t1 = t0;
    variable Boolean running = false;
    shared Stopwatch start() {
        running = true;
        t0 = system.nanoseconds;
        return this;
    }
    shared Stopwatch stop() {
        t1 = system.nanoseconds;
        running = false;
        return this;
    }
    shared Integer read => running then system.nanoseconds-t0 else t1-t0;
}

class SerializationResult(totalTime, addTime, serTime, serializedResult) {
    shared Integer totalTime;
    shared Integer addTime;
    shared Integer serTime;
    shared String serializedResult;
}

/*"Return the time it took to serialize an object, along with its serialized representation"
SerializationResult timeSerial(Factura f) {
  value totalTime = Stopwatch();
  value serTime = Stopwatch();
  value addTime = Stopwatch();
  totalTime.start();
  value ser = Serializer();
  addTime.start();
  ser.add(f);
  addTime.stop();
  serTime.start();
  value json = ser.json;
  serTime.stop();
  return SerializationResult(totalTime.read, addTime.read, serTime.read, json);
}
*/
class DeserializationResult(totalTime, restored) {
    shared Integer totalTime;
    shared Object restored;
}

DeserializationResult timeParse(String json) {
  value t0 = Stopwatch().start();
  value restored = Deserializer { 
        clazz = `Factura`;
        typeHinting = PropertyTypeHint{
            naming = LogicalTypeNaming(HashMap{
                "Person" -> `NullPerson`,
                "Address" -> `NullAddress`,
                "Item" -> `NullItem`,
                "Product" -> `NullProduct`,
                "Invoice" -> `NullInvoice`
            });
        }; 
    }.deserialize(StreamParser(StringTokenizer(json)));
  //value restored = deser.parse(json).first;
  t0.stop();
  //assert(is Factura restored);
  return DeserializationResult(t0.read, restored);
}

void statSer({SerializationResult*} data) {
  assert(nonempty times = [ for (d in data) d.totalTime ]);
  print("MIN: ``min(times)/1_000_000.0``");
  print("MAX: ``max(times)/1_000_000.0``");
  print("AVG: ``sum(times)/data.size/1_000_000.0``");
  
  assert(nonempty sertimes = [ for (d in data) d.serTime ]);
  print("ser AVG: ``sum(sertimes)/data.size/1_000_000.0``");
  assert(nonempty addtimes = [ for (d in data) d.addTime ]);
  print("add AVG: ``sum(addtimes)/data.size/1_000_000.0``");
}

void statDeser({DeserializationResult*} data) {
    assert(nonempty times = [ for (d in data) d.totalTime ]);
    print("MIN: ``min(times)/1_000_000.0``");
    print("MAX: ``max(times)/1_000_000.0``");
    print("AVG: ``sum(times)/data.size/1_000_000.0``");
    
    //value sertimes = [ for (d in data) d.serTime ];
    //print("ser AVG: ``sum(sertimes)/data.size``");
    //value addtimes = [ for (d in data) d.addTime ];
    //print("add AVG: ``sum(addtimes)/data.size``");
}

shared void run2() {
    
  value factura = crear();
  print(factura);
  //warmup
  variable value times = 1000;
  /*for (i in 1..1) {
      value json = timeSerial(factura);
      print(json.serializedResult);
      timeParse(json.serializedResult);
  }
  //measure
  times = 100;
  print("Encoding ``times`` times");
  value encodeTimes = ArrayList<SerializationResult>(times);
  for (i in 1..times) {
      encodeTimes.add(timeSerial(factura));
  }
  print("Decoding ``times`` times");
  value decodeTimes = ArrayList<DeserializationResult>(times);
  for (i in encodeTimes) {
      decodeTimes.add(timeParse(i.serializedResult)); 
  }
  for (d in decodeTimes) {
    assert(d.restored.string == factura.string);
  }
  print("Encoding times:");
  statSer(encodeTimes);
  print("Decoding times:");
  statDeser(decodeTimes);
   */
  for (i in 1..times) {
      timeParse(jsonFactura);
  }
  value d = ArrayList<DeserializationResult>();
  for (i in 1..times) {
    d.add(timeParse(jsonFactura));
  }
  statDeser(d);
}
