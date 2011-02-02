﻿package {
	
	public class Mustache  {

		private var otag:String = "{{";
		private var ctag:String = "}}";
		private var pragmas:Object = {};
		private var buffer:Array = [];
		private var pragmas_implemented:Object = {"IMPLICIT-ITERATOR":true};
		private var send:Function;
		
		public function Mustache() {
			//trace("mustache instantiated!");
		}
		
		public function to_html(template:String, view:Object, partials:Object = null, send_fun:Function = null):String
		{
			if(send_fun != null)
			{
				send = send_fun;
			}
			else
			{
				var that:Mustache = this;
				send = function(line:String):void {
					if(line != "") {
						that.buffer.push(line);
					}
				}
			}
			
			render(template, view, partials);
			if(send_fun == null)
			{
				return buffer.join("\n");
			}
			
			return null;
		}
			
		private function render( template:String, context:Object, partials:Object = null, in_recursion:Boolean = false):String
		{
			trace("render() " + template);
			var ret:String;
			
			buffer = [];
			if(!includes("", template))
			{
				if(in_recursion)
				{
					return template;
				}
				else
				{
					send(template);
					return null;
				}
			}
			
			if(!in_recursion)
			{
				buffer = [];
			}
			
			template = render_pragmas( template );
			
			var html:String = render_section( template, context, partials );
			
			if(in_recursion)
			{
				ret = render_tags( html, context, partials, in_recursion );
				trace("render_tags: " + ret);
				return ret;
			}
			
			render_tags( html, context, partials, in_recursion );
			return html;
		}
		
		
		private function render_pragmas( template:String ):String
		{
			if(!includes("%", template))
			{
				return template;
			}
			
			var that:Mustache = this;
			var regex:RegExp = new RegExp(otag + "%([\\w_-]+) ?([\\w]+=[\\w]+)?" + ctag);
			
			return template.replace(regex, function( match:String, pragma:String, options:String, pos:int, original:String ):String {
																			if(!pragmas_implemented[pragma]) {
																				throw new Error("This implementation of mustache doesn't understand the '" + pragma + "' pragma.");
																			}
																			that.pragmas[pragma] = {};
																			if(options) {
																				var opts:Array = options.split("=");
																				that.pragmas[pragma][opts[0]] = opts[1];
																			}
																			return "";
																			});
		}
		
		
		private function render_partial( name:String, context:Object, partials:Object):String
		{
			if(!partials || !partials[name])
			{
				throw new Error("Unknown partial '" + name + "'.");
			}
//			if(typeof(context[name]) != "object")
//			{
//				trace("-- render_partial, cut out! " + context[name]);
//				return partials[name];
//			}
			return render(partials[name], context, partials, true);
		}
		
		
		private function render_section(template:String, context:Object, partials:Object):String
		{
			if(!includes("#", template) && !includes("^", template))
			{
				return template;
			}
			
			var that:Mustache = this;
			
			var regex:RegExp = new RegExp(otag + "(\\^|\\#)(.+)" + ctag + "\\s*([\\s\\S]+?)" + otag + "\\/\\2" + ctag + "\\s*", "mg");
			
			return template.replace(regex, function(match:String, type:String, name:String, content:String, pos:int, original:String):String{
																			   var value:* = that.find(name, context);
																				 if(type =="^"){
																				   if(!value || value is Array && value.length == 0) {
																					   return render(content, context, partials, true);
																				   }else{
																					   return "";
																				   }
																			   }else if(type == "#"){
																				   if(value is Array){
																					   return that.map(value, function(row:*):* {
																														   return that.render(content, that.merge(context, that.create_context(row)), partials, true);
																														   }).join("");
																				   }else if(value is Function) {
																					   return value.call(context, content, function(text:String):String {
																																		 return that.render(text, context, partials, true);
																																		 })
																				   }else if(!(value is Boolean) && !(value is String)){
																					   return that.render(content, 
																										  that.merge(context, that.create_context(value)), partials, true);
																				   }else if(value) {
																					   return that.render(content, context, partials, true);
																				   } else {
																					   return "";
																				   }
																			   }
																			    return match;
																			   });
		
																					   
		}
		
		private function render_tags(template:String, context:Object, partials:Object, in_recursion:Boolean):String
		{
			var that:Mustache = this;
			var new_regex:Function = function():RegExp
			{
				return new RegExp(that.otag + "(=|!|>|\\{|%)?([^\/#\^\]+?)\\1?" + that.ctag + "+", "g");
			}
			var regex:RegExp = new_regex();
			var lines:Array = template.split("\n");
			for(var i:int = 0; i < lines.length; i++) {
				lines[i] = String(lines[i]).replace(regex, function(match:String, operator:String, name:String, pos:int, original:String):String {
					trace(match + ":" + operator + ":" + name);
					switch(operator){
						case "!":
							return "";
						case "=":
							that.set_delimiters(name);
							regex = new_regex();
							return "";
						case ">":
							return that.render_partial(that.trim(name), context, partials);
						case "{":
							return that.find(name, context);
						default:
							return that.escape(that.find(name, context));
						}
				});
				if(!in_recursion){
					this.send(lines[i]);
				}
			}
			
			if(in_recursion){
				return lines.join("\n");
			}
			
			return "";
							
		}
		
		private function set_delimiters(delimiters:String):void
		{
			var dels:Array = delimiters.split(" ");
			otag = escape_regex(dels[0]);
			ctag = escape_regex(dels[1]);
		}
		
		private function escape_regex(text:String):String
		{
			if(!arguments.callee.sRE){
				var specials:Array = [
								'/', '.', '*', '+', '?', '|',
								'(', ')', '[', ']', '{', '}', '\\'
								];
				arguments.callee.sRE = new RegExp('(\\' + specials.join('|\\') + ')', 'g');
			}
			return text.replace(arguments.callee.sRE, '\\$1');
		}
		
		
		private function find(name:String, context:Object):*
		{
			name = trim(name);
			if(typeof context[name] === "function"){
				return context[name].apply(context);
			}
			if(context[name] != undefined){
				return context[name];
			}
			return "";
		}
		
		private function includes(needle:*, haystack:*):Boolean
		{
			return haystack.indexOf(otag + needle) != -1;
		}
		
		
		private function escape(s:String):String {
			return ((s== null) ? "" : s).toString().replace(/&(?!\w+;)|["<>\\]/g, function (s:String, pos:int, original:String):String{
				switch(s){
					case "&": return "&amp;";
					case "\\": return "\\\\";;
					case '"': return '\"';;
					case "<": return "&lt;";
					case ">": return "&gt;";
					default: return s;
				}
																							  });
		}
		
		private function merge(a:*, b:*):Object{
			trace("merge()");
			var _new:Object = {};
			var name:String;
			
			for( name in a){
				if(a.hasOwnProperty(name)){
					trace("a: " + name + "=" + a[name]);
					_new[name] = a[name];
				}
			}
			for( name in b){
				if(b.hasOwnProperty(name)){
					trace("b: " + name + "=" + b[name]);
					_new[name] = b[name];
				}
			}
			
			for(name in _new)
			{
				trace("new: " + name + "=" + _new[name]);
			}
			return _new;
		}
		
		private function create_context(_context:*):*
		{
			var aval:String;
			trace("create_context()");
			for(aval in _context)
			{
				trace("-- " + aval + ": " + _context[aval]);
			}
			if(is_object(_context)){
				return _context;
			} else if(pragmas["IMPLICIT-ITERATOR"]){
				var iterator:String = pragmas["IMPLICIT-ITERATOR"].iterator || ".";
				var ctx:Object = {};
				ctx[iterator] = _context;
				return ctx;
			}
			return new Object();
		}
		
		private function is_object(a:*):Boolean {
			return a && typeof a == "object";
		}
		
		private function is_array(a:*):Boolean {
			return a is Array;
		}
		
		private function trim(s:String):String {
			return s.replace(/^\s*|\s*$/g, "");
		}
		
		private function map(array:Array, fn:Function):Array {
			trace("map()")
			if(array.map is Function) {
				trace("array.map(fn)");
				var ret:Array = array.map(fn);
				trace(ret);
				return ret;
			} else {
				var val:*;
				var r:Array = [];
				var l:int = array.length;
				for(var i:int = 0; i < l; i++) {
					val = fn(array[i]);
					r.push(fn(array[i]));
				}
				return r;
			}
		}
		
		
	}
}
