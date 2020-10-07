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
import org.apache.royale.reflection.VariableDefinition;
import org.apache.royale.reflection.getDefinitionByName;

	import org.swiftsuspenders.InjectionConfig;
	import org.swiftsuspenders.Injector;
	import org.swiftsuspenders.InjectorError;

	public class PropertyInjectionPoint extends InjectionPoint
	{
		/*******************************************************************************************
		*								private properties										   *
		*******************************************************************************************/
		private var _propertyName : String;
		private var _propertyType : String;
		private var _injectionName : String;

		private var _varDef:VariableDefinition;

		
		/*******************************************************************************************
		*								public methods											   *
		*******************************************************************************************/
		public function PropertyInjectionPoint(def : DefinitionWithMetaData, injector : Injector = null)
		{
			super(def, null);
		}
		
		override public function applyInjection(target : Object, injector : Injector) : Object
		{
			var injectionConfig : InjectionConfig = injector.getMapping(Class(
					getDefinitionByName(_propertyType)
					/*injector.getApplicationDomain().getDefinition(_propertyType)*/), _injectionName);
			var injection : Object = injectionConfig.getResponse(injector);
			if (injection == null)
			{
				throw(new InjectorError(
						'Injector is missing a rule to handle injection into property "' +
						_propertyName + '" of object "' + target +
						'". Target dependency: "' + _propertyType + '", named "' + _injectionName +
						'"'));
			}
			target[_propertyName] = injection;
			return target;
		}


		/*******************************************************************************************
		*								protected methods										   *
		*******************************************************************************************/
		override protected function initializeInjection(def : DefinitionWithMetaData) : void
		{
			_varDef = def as VariableDefinition;
			_propertyName = def.name;
			_propertyType = _varDef.type.qualifiedName;
			var injects:Array = def.retrieveMetaDataByName('Inject');
			var injectData:MetaDataDefinition = injects[0] as MetaDataDefinition;
			var args:Array = injectData.getArgsByKey('value');
			if (args.length) {
				var arg:MetaDataArgDefinition = args[0] as MetaDataArgDefinition;
				_injectionName = arg.value
			} else {
				_injectionName = '';
			}


/*			_propertyType = node.parent().@type.toString();
			_propertyName = node.parent().@name.toString();
			_injectionName = node.arg.attribute('value').toString();*/
		}
	}
}