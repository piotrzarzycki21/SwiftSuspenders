/*
 * Copyright (c) 2009 the original author or authors
 * 
 * Permission is hereby granted to use, modify, and distribute this file 
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.swiftsuspenders.injectionpoints
{
import org.apache.royale.debugging.throwError;
import org.apache.royale.reflection.DefinitionWithMetaData;
import org.apache.royale.reflection.MetaDataArgDefinition;
import org.apache.royale.reflection.MetaDataDefinition;
import org.apache.royale.reflection.MethodDefinition;
import org.apache.royale.reflection.ParameterDefinition;
import org.apache.royale.reflection.getQualifiedClassName;
	import org.apache.royale.reflection.getDefinitionByName;


	import org.swiftsuspenders.InjectionConfig;
	import org.swiftsuspenders.Injector;
	import org.swiftsuspenders.InjectorError;

	public class MethodInjectionPoint extends InjectionPoint
	{
		/*******************************************************************************************
		*								private properties										   *
		*******************************************************************************************/
		protected var methodName : String;
		protected var _parameterInjectionConfigs : Array;
		protected var requiredParameters : int = 0;

		protected var _methodDef:MethodDefinition;
		
		
		/*******************************************************************************************
		*								public methods											   *
		*******************************************************************************************/
		public function MethodInjectionPoint(def : DefinitionWithMetaData, injector : Injector = null)
		{
			super(def, injector);
		}
		
		override public function applyInjection(target : Object, injector : Injector) : Object
		{
			var parameters : Array = gatherParameterValues(target, injector);
		/*	var method : Function = target[methodName];
			method.apply(target, parameters);*/

			_methodDef.getMethod(target).apply(target, parameters);

			return target;
		}


		/*******************************************************************************************
		*								protected methods										   *
		*******************************************************************************************/
		override protected function initializeInjection(def : DefinitionWithMetaData) : void
		{
			var methodDef:MethodDefinition = def as MethodDefinition;
			_methodDef = methodDef;
			//@todo remove this, debugging of ported code:
			if (!methodDef) throwError('initializeInjection is not processing an actual MethodDefinition');

			var injects:Array = def.retrieveMetaDataByName('Inject');
			var injectData:MetaDataDefinition = injects[0] as MetaDataDefinition;

			var nameArgs:Array = injectData.getArgsByKey('name');


		//	var nameArgs : XMLList = node.arg.(@key == 'name');
		//	var methodNode : XML = node.parent();
			methodName = methodDef.name;
			
			gatherParameters(methodDef, nameArgs);
		}

		protected function gatherParameters(methodDef : MethodDefinition, nameArgs : Array) : void
		{
			_parameterInjectionConfigs = [];
			var i : int = 0;

			for each (var parameter : ParameterDefinition in methodDef.parameters)
			{
				var injectionName : String = '';
				if (nameArgs[i])
				{
					injectionName = (nameArgs[i] as MetaDataArgDefinition).value;
				}
				var parameterTypeName : String = parameter.type.qualifiedName;
				if (parameterTypeName == '*')
				{
					if (parameter.optional) {
						throw new InjectorError('Error in method definition of injectee. ' +methodDef.owner.qualifiedName +
								' Required parameters can\'t have type "*".');
					} else {
						parameterTypeName = null;
					}
				}
				_parameterInjectionConfigs.push(
						new ParameterInjectionConfig(parameterTypeName, injectionName));

				if (!parameter.optional) requiredParameters++;
				i++;
			}
		}
		
		/*protected function gatherParameters(methodNode : XML, nameArgs : XMLList) : void
		{
			_parameterInjectionConfigs = [];
			var i : int = 0;
			for each (var parameter : XML in methodNode.parameter)
			{
				var injectionName : String = '';
				if (nameArgs[i])
				{
					injectionName = nameArgs[i].@value.toString();
				}
				var parameterTypeName : String = parameter.@type.toString();
				if (parameterTypeName == '*')
				{
					if (parameter.@optional.toString() == 'false')
					{
						//TODO: Find a way to trace name of affected class here
						throw new InjectorError('Error in method definition of injectee. ' +
							'Required parameters can\'t have type "*".');
					}
					else
					{
						parameterTypeName = null;
					}
				}
				_parameterInjectionConfigs.push(
						new ParameterInjectionConfig(parameterTypeName, injectionName));
				if (parameter.@optional.toString() == 'false')
				{
					requiredParameters++;
				}
				i++;
			}
		}*/
		
		protected function gatherParameterValues(target : Object, injector : Injector) : Array
		{
			var parameters : Array = [];
			var length : int = _parameterInjectionConfigs.length;
			for (var i : int = 0; i < length; i++)
			{
				var parameterConfig : ParameterInjectionConfig = _parameterInjectionConfigs[i];
				var config : InjectionConfig = injector.getMapping(Class(
						getDefinitionByName(parameterConfig.typeName)
						/*injector.getApplicationDomain().getDefinition(parameterConfig.typeName)*/),
						parameterConfig.injectionName);
				var injection : Object = config.getResponse(injector);
				if (injection == null)
				{
					if (i >= requiredParameters)
					{
						break;
					}
					throw(new InjectorError(
						'Injector is missing a rule to handle injection into target ' + target + 
						'. Target dependency: ' + getQualifiedClassName(config.request) + 
						', method: ' + methodName + ', parameter: ' + (i + 1)
					));
				}
				
				parameters[i] = injection;
			}
			return parameters;
		}
	}
}

final class ParameterInjectionConfig
{
	public var typeName : String;
	public var injectionName : String;

	public final function ParameterInjectionConfig(typeName : String, injectionName : String)
	{
		this.typeName = typeName;
		this.injectionName = injectionName;
	}
}