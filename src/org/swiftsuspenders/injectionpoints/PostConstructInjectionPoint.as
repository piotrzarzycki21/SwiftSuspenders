/*
* Copyright (c) 2009 the original author or authors
* 
* Permission is hereby granted to use, modify, and distribute this file 
* in accordance with the terms of the license agreement accompanying it.
*/

package org.swiftsuspenders.injectionpoints
{
import org.apache.royale.reflection.DefinitionWithMetaData;
import org.apache.royale.reflection.MetaDataArgDefinition;
import org.apache.royale.reflection.MetaDataDefinition;
import org.apache.royale.reflection.MethodDefinition;
import org.swiftsuspenders.Injector;
	
	public class PostConstructInjectionPoint extends InjectionPoint
	{
		/*******************************************************************************************
		 *								private properties										   *
		 *******************************************************************************************/
		protected var methodName : String;
		protected var orderValue:int;
		
		protected var _methodDef:MethodDefinition;
		/*******************************************************************************************
		 *								public methods											   *
		 *******************************************************************************************/
		public function PostConstructInjectionPoint(def:DefinitionWithMetaData, injector : Injector = null)
		{
			super(def, injector);
		}
		
		public function get order():int
		{
			return orderValue;
		}

		override public function applyInjection(target : Object, injector : Injector) : Object
		{

			target[methodName]();
			return target;
		}
		
		
		/*******************************************************************************************
		 *								protected methods										   *
		 *******************************************************************************************/
		override protected function initializeInjection(def:DefinitionWithMetaData) : void
		{
			_methodDef = def as MethodDefinition;
			var postConstructs:Array = def.retrieveMetaDataByName('PostConstruct');
			var postConstructData:MetaDataDefinition = postConstructs[0] as MetaDataDefinition;

			var orderArg:Array = postConstructData.getArgsByKey('order');
			orderValue = orderArg.length ? int((orderArg[0] as MetaDataArgDefinition).value) : 0;
			/*var orderArg : XMLList = node.arg.(@key == 'order');
			var methodNode : XML = node.parent();
			orderValue = int(orderArg.@value);*/
			methodName = _methodDef.name;
		}
	}
}