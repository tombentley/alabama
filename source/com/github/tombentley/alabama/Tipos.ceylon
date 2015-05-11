shared serializable class Factura(numero,fecha,autor,destino,items,impuesto=16.0,descuento=0.0) {
  shared Integer numero;
  shared Entidad autor;
  shared Entidad destino;
  shared Integer fecha;
  shared [Itemo+] items;
  shared Float impuesto;
  shared Float descuento;
  shared actual String string {
    value subtotal = sum(items.map((i)=>i.producto.precio*i.cantidad));
    value tax = subtotal * impuesto / 100.00;
    return "FACTURA # ``numero``
            EXPIDE:  ``autor.nombre``
                     RFC ``autor.rfc``
                     ``autor.domicilio``
            CLIENTE: ``destino.nombre``
                     RFC ``destino.rfc``
                     ``destino.domicilio``
            DETALLE:  ``items``
            SUBTOTAL: $ ``subtotal``
            IMPUESTO: $ ``tax`` (``impuesto``%)
            TOTAL:    $ ``subtotal+tax``";
  }
}

shared serializable class Entidad(nombre,rfc,domicilio) {
  shared String nombre;
  shared String rfc;
  shared Domicilio domicilio;
}

shared serializable class Domicilio(calle,numExt,numInt,colonia,municipio,estado,cp,pais) {
  shared String calle;
  shared String numExt;
  shared String? numInt;
  shared String colonia;
  shared String municipio;
  shared String estado;
  shared String pais;
  shared String cp;
  string=>"``calle`` #``numExt``
           Col. ``colonia``
           ``municipio``,``estado``
           CP ``cp`` ``pais``";
}

shared serializable class Itemo(producto,cantidad) {
  shared Producto producto;
  shared Integer cantidad;
  string => "``producto`` x``cantidad``";
}

shared serializable class Producto(nombre,sku,precio) {
  shared String nombre;
  shared String sku;
  shared Float precio;
  string => "PROD[``nombre`` (``sku``) $``precio``]";
}
