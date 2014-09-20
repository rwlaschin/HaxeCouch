
package memcache;

import sys.net.Socket;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

class Host {
    public var ip(default,default) : sys.net.Host;
    public var port(default,default) : Int;

    function get_ip() { return ip; }
    function get_port() { return port; }

    public function new ( host:String, port:Int) {
        this.ip = new sys.net.Host(host);
        this.port = port;
    }
}

class MemcacheSocket {
    private var defaultPort:Int = 11211;
    private var socket:sys.net.Socket = null;

    private var _host:Host;

    public function new( host:String, _port:Null<Int> = null ) {
        this._host = new Host (
                        host,
                        (_port != null ? _port : defaultPort)
                    );
        this.socket = new sys.net.Socket();
        open();
    }

    private function open() : Void {
        try {
            socket.connect( _host.ip, _host.port );
        } catch (e:Dynamic) {
            trace( Std.string(e) );
        }
    }

    private function close() : Void {
        try {
            socket.close();
        } catch (e:String) {
            trace(e);
        }
    }

    private function encode( data:Dynamic ):String {
        return Std.string(data);
    }

    private function decode( data:String, len:Int ):Dynamic {
        return Std.string(data);
    }

    public function send( command:String,
                           key:String, data:Dynamic, expire:Int = 0,
                           flags:Int = 0, cas:Null<Int> = null, noreply:Bool=false ):Void {
        // https://github.com/memcached/memcached/blob/master/doc/protocol.txt

        try {
            // <command name> <key> <flags> <exptime> <bytes> <cas> [noreply] <b:datablock>\r\n
            if( cas == null ) { cas = 0; }

            var byter:haxe.io.BytesOutput = new haxe.io.BytesOutput();
            var encoded:String = this.encode(data);
            byter.writeString( encoded );
            var data:Bytes = byter.getBytes();

            var message:String = "";
            message += command + " ";
            message += key + " ";
            message += flags + " "; // this can be used to communicate the storage type
            message += expire + " ";
            message += data.length + " ";
            message += cas + " ";
            message += ( noreply  ? "noreply " : "" );

            trace(message + " " + encoded );

            // TODO: Add failure handling/retries
            socket.output.writeString( message );
            socket.output.writeFullBytes( data, 0, data.length );
            socket.output.writeString( "\r\n" );
        } catch (e:Dynamic) {
            trace(Std.string(e));
        }
    }

    public function read():String {
        // https://github.com/memcached/memcached/blob/master/doc/protocol.txt

        try {
            // TODO: Add failure handling/retries
            var message = "";
            var readByte : Int = -1;
            while( readByte != 0 ) {
                readByte = socket.input.readByte();
                trace("Byte - " + Std.string(readByte) );
                message += String.fromCharCode(readByte);
                if( readByte != 0x20 && readByte != 0x0D && readByte != 0x0A && readByte != 0 ) {
                    continue;
                }
                trace("Read so far - " + Std.string(message) );
                var type:String = message;
                switch(type) {
                    default: 
                    case " ": case "\r" : case "\n":
                        message = ""; // remove and keep processing
                        break;
                    case "ERROR": 
                        message = ""; // remove and keep processing
                        return type;
                    case "NOT_STORED": case "NOT_FOUND":
                        message = "";
                        return "Failed - " + type;
                    case "STORED": case "EXISTS": case "TOUCHED":
                        message = "";
                        return type;
                }
            }
        } catch (e:Dynamic) {
            trace( Std.string(e) );
        }
        return "";
    }
}