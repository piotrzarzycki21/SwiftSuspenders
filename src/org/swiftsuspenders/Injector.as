/*
 * Copyright (c) 2009-2010 the original author or authors
 * 
 * Permission is hereby granted to use, modify, and distribute this file 
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.swiftsuspenders
{

	import org.apache.royale.reflection.MethodDefinition;
	import org.apache.royale.reflection.TypeDefinition;
	import org.apache.royale.reflection.VariableDefinition;
	import org.apache.royale.reflection.utils.MemberTypes;
	import org.apache.royale.reflection.utils.getMembersWithMetadata;

	COMPILE::SWF {
		import flash.utils.Dictionary;
		import flash.utils.Proxy;
	}
	import org.apache.royale.reflection.describeType;
	//import flash.system.ApplicationDomain;

	import org.apache.royale.reflection.getDefinitionByName;
	import org.apache.royale.reflection.getQualifiedClassName;
	
	import org.swiftsuspenders.injectionpoints.ConstructorInjectionPoint;
	import org.swiftsuspenders.injectionpoints.InjectionPoint;
	import org.swiftsuspenders.injectionpoints.MethodInjectionPoint;
	import org.swiftsuspenders.injectionpoints.NoParamsConstructorInjectionPoint;
	import org.swiftsuspenders.injectionpoints.PostConstructInjectionPoint;
	import org.swiftsuspenders.injectionpoints.PropertyInjectionPoint;
	import org.swiftsuspenders.injectionresults.InjectClassResult;
	import org.swiftsuspenders.injectionresults.InjectOtherRuleResult;
	import org.swiftsuspenders.injectionresults.InjectSingletonResult;
	import org.swiftsuspenders.injectionresults.InjectValueResult;

	public class Injector
	{
		/*******************************************************************************************
		*								private properties										   *
		*******************************************************************************************/
		COMPILE::SWF
		private static var INJECTION_POINTS_CACHE : Dictionary = new Dictionary(true);
		COMPILE::JS
		private static var INJECTION_POINTS_CACHE : WeakMap = new WeakMap();


		private var m_parentInjector : Injector;
    //    private var m_applicationDomain:ApplicationDomain;
		private var m_mappings : Object /*Dictionary*/;
		COMPILE::SWF
		private var m_injecteeDescriptions : Dictionary;
		COMPILE::JS
		private var m_injecteeDescriptions : WeakMap;

		COMPILE::SWF
		private var m_attendedToInjectees : Dictionary;
		COMPILE::JS
		private var m_attendedToInjectees : WeakMap;

		private var m_xmlMetadata : XML;
		
		
		/*******************************************************************************************
		*								public methods											   *
		*******************************************************************************************/
		public function Injector(xmlConfig : XML = null)
		{
			m_mappings = {}; //new Dictionary();
			if (xmlConfig != null)
			{
				COMPILE::SWF{
					m_injecteeDescriptions = new Dictionary(true);
				}
				COMPILE::JS{
					m_injecteeDescriptions = new WeakMap();
				}
			}
			else
			{
				m_injecteeDescriptions = INJECTION_POINTS_CACHE;
			}
			COMPILE::SWF{
				m_attendedToInjectees = new Dictionary(true);
			}
			COMPILE::JS{
				m_attendedToInjectees = new WeakMap();
			}
			m_xmlMetadata = xmlConfig;
		}
		
		public function mapValue(whenAskedFor : Class, useValue : Object, named : String = "") : *
		{
			var config : InjectionConfig = getMapping(whenAskedFor, named);
			config.setResult(new InjectValueResult(useValue));
			return config;
		}
		
		public function mapClass(
				whenAskedFor : Class, instantiateClass : Class, named : String = "") : *
		{
			var config : InjectionConfig = getMapping(whenAskedFor, named);
			config.setResult(new InjectClassResult(instantiateClass));
			return config;
		}
		
		public function mapSingleton(whenAskedFor : Class, named : String = "") : *
		{
			return mapSingletonOf(whenAskedFor, whenAskedFor, named);
		}
		
		public function mapSingletonOf(
			whenAskedFor : Class, useSingletonOf : Class, named : String = "") : *
		{
			var config : InjectionConfig = getMapping(whenAskedFor, named);
			config.setResult(new InjectSingletonResult(useSingletonOf));
			return config;
		}
		
		public function mapRule(whenAskedFor : Class, useRule : *, named : String = "") : *
		{
			var config : InjectionConfig = getMapping(whenAskedFor, named);
			config.setResult(new InjectOtherRuleResult(useRule));
			return useRule;
		}
		
		public function getMapping(whenAskedFor : Class, named : String = "") : InjectionConfig
		{
			var requestName : String = getQualifiedClassName(whenAskedFor);
			var config : InjectionConfig = m_mappings[requestName + '#' + named];
			if (!config)
			{
				config = m_mappings[requestName + '#' + named] =
					new InjectionConfig(whenAskedFor, named);
			}
			return config;
		}
		
		public function injectInto(target : Object) : void
		{

			COMPILE::SWF{
				if (m_attendedToInjectees[target])
				{
					return;
				}
				m_attendedToInjectees[target] = true;
			}

			COMPILE::JS{
				if (m_attendedToInjectees.has(target))
				{
					return;
				}
				m_attendedToInjectees.set(target, true);
			}

			//get injection points or cache them if this target's class wasn't encountered before
			var targetClass : Class = getConstructor(target);
			var injecteeDescription : InjecteeDescription

			COMPILE::SWF{
				injecteeDescription = m_injecteeDescriptions[targetClass] || getInjectionPoints(targetClass);
			}

			COMPILE::JS{
				injecteeDescription = m_injecteeDescriptions.get(targetClass) || getInjectionPoints(targetClass);
			}

			var injectionPoints : Array = injecteeDescription.injectionPoints;
			var length : int = injectionPoints.length;
			for (var i : int = 0; i < length; i++)
			{
				var injectionPoint : InjectionPoint = injectionPoints[i];
				injectionPoint.applyInjection(target, this);
			}

		}
		
		public function instantiate(clazz:Class):*
		{
			var injecteeDescription : InjecteeDescription;
			COMPILE::SWF{
				injecteeDescription = m_injecteeDescriptions[clazz];
			}

			COMPILE::JS{
				injecteeDescription = m_injecteeDescriptions.get(clazz);
			}

			if (!injecteeDescription)
			{
				injecteeDescription = getInjectionPoints(clazz);
			}
			var injectionPoint : InjectionPoint = injecteeDescription.ctor;
			var instance : * = injectionPoint.applyInjection(clazz, this);
			injectInto(instance);
			return instance;
		}
		
		public function unmap(clazz : Class, named : String = "") : void
		{
			var mapping : InjectionConfig = getConfigurationForRequest(clazz, named);
			if (!mapping)
			{
				throw new InjectorError('Error while removing an injector mapping: ' +
					'No mapping defined for class ' + getQualifiedClassName(clazz) +
					', named "' + named + '"');
			}
			mapping.setResult(null);
		}

		public function hasMapping(clazz : Class, named : String = '') : Boolean
		{
			var mapping : InjectionConfig = getConfigurationForRequest(clazz, named);
			if (!mapping)
			{
				return false;
			}
			return mapping.hasResponse(this);
		}

		public function getInstance(clazz : Class, named : String = '') : *
		{
			var mapping : InjectionConfig = getConfigurationForRequest(clazz, named);
			if (!mapping || !mapping.hasResponse(this))
			{
				throw new InjectorError('Error while getting mapping response: ' +
					'No mapping defined for class ' + getQualifiedClassName(clazz) +
					', named "' + named + '"');
			}
			return mapping.getResponse(this);
		}
		
		public function createChildInjector(/*applicationDomain:ApplicationDomain=null*/) : Injector
		{
			var injector : Injector = new Injector();
         //   injector.setApplicationDomain(applicationDomain);
			injector.setParentInjector(this);
			return injector;
		}
        
       /* public function setApplicationDomain(applicationDomain:ApplicationDomain):void
        {
            m_applicationDomain = applicationDomain;
        }
        
        public function getApplicationDomain():ApplicationDomain
        {
            return m_applicationDomain ? m_applicationDomain : ApplicationDomain.currentDomain;
        }*/

		public function setParentInjector(parentInjector : Injector) : void
		{
			//restore own map of worked injectees if parent injector is removed
			if (m_parentInjector && !parentInjector)
			{
				COMPILE::SWF{
					m_attendedToInjectees = new Dictionary(true);
				}

				COMPILE::JS{
					m_attendedToInjectees = new WeakMap();
				}
			}
			m_parentInjector = parentInjector;
			//use parent's map of worked injectees
			if (parentInjector)
			{
				m_attendedToInjectees = parentInjector.attendedToInjectees;
			}
		}
		
		public function getParentInjector() : Injector
		{
			return m_parentInjector;
		}

		public static function purgeInjectionPointsCache() : void
		{
			COMPILE::SWF {
				INJECTION_POINTS_CACHE = new Dictionary(true);
			}

			COMPILE::JS {
				INJECTION_POINTS_CACHE = new WeakMap();
			}
		}
		
		
		/*******************************************************************************************
		*								internal methods										   *
		*******************************************************************************************/
		internal function getAncestorMapping(
				whenAskedFor : Class, named : String = null) : InjectionConfig
		{
			var parent : Injector = m_parentInjector;
			while (parent)
			{
				var parentConfig : InjectionConfig =
					parent.getConfigurationForRequest(whenAskedFor, named, false);
				if (parentConfig && parentConfig.hasOwnResponse())
				{
					return parentConfig;
				}
				parent = parent.getParentInjector();
			}
			return null;
		}

		COMPILE::SWF
		internal function get attendedToInjectees() : Dictionary
		{
			return m_attendedToInjectees;
		}
		COMPILE::JS
		internal function get attendedToInjectees() : WeakMap
		{
			return m_attendedToInjectees;
		}
		
		/*******************************************************************************************
		*								private methods											   *
		*******************************************************************************************/
		private function getInjectionPoints(clazz : Class) : InjecteeDescription
		{
			var description : TypeDefinition = describeType(clazz);

			if (description.kind == 'interface') {
				throw new InjectorError('Interfaces can\'t be used as instantiatable classes.');
			}
			/*if (description.@name != 'Object' && description.factory.extendsClass.length() == 0)
			{
				throw new InjectorError('Interfaces can\'t be used as instantiatable classes.');
			}*/
			var injectionPoints : Array = [];
			//var node : XML;
			
			// This is where we have to wire in the XML...
			if(m_xmlMetadata)
			{
				throw new Error('support for XML config needs to be added')
			/*	createInjectionPointsFromConfigXML(description);
				addParentInjectionPoints(description, injectionPoints);*/
			}

			//get constructor injections
			var ctorInjectionPoint : InjectionPoint;

			var constructorMethod:MethodDefinition = description.constructorMethod;
			const paramDefinitions:Array = constructorMethod.parameters;
		//	node = description.factory.constructor[0];
			if (paramDefinitions.length == 0) {
				ctorInjectionPoint = new NoParamsConstructorInjectionPoint();
			} else {
				ctorInjectionPoint = new ConstructorInjectionPoint(constructorMethod, clazz, this);
			}


			var injectionPoint : InjectionPoint;
			var injectableProperties:Array = getMembersWithMetadata(description, 'Inject', false, MemberTypes.ACCESSORS|MemberTypes.VARIABLES);

			for each(var varDef:VariableDefinition in injectableProperties) {
				injectionPoint = new PropertyInjectionPoint(varDef);
				injectionPoints.push(injectionPoint);
			}

			var injectableMethods:Array = getMembersWithMetadata(description, 'Inject', false, MemberTypes.METHODS);
			for each (var methodDef:MethodDefinition in injectableMethods)
			{
				injectionPoint = new MethodInjectionPoint(methodDef, this);
				injectionPoints.push(injectionPoint);
			}

			var postConstructMethodPoints : Array = [];

			var postContructMethods:Array = getMembersWithMetadata(description, 'PostConstruct', false, MemberTypes.METHODS);
			for each (methodDef in postContructMethods)
			{
				injectionPoint = new PostConstructInjectionPoint(methodDef, this);
				postConstructMethodPoints.push(injectionPoint);
			}
			if (postConstructMethodPoints.length > 0)
			{
				postConstructMethodPoints.sortOn("order", Array.NUMERIC);
				injectionPoints.push.apply(injectionPoints, postConstructMethodPoints);
			}


			//get injection points for variables
			/*for each (node in description.factory.*.
				(name() == 'variable' || name() == 'accessor').metadata.(@name == 'Inject'))
			{
				injectionPoint = new PropertyInjectionPoint(node);
				injectionPoints.push(injectionPoint);
			}*/
		
			//get injection points for methods
			/*for each (node in description.factory.method.metadata.(@name == 'Inject'))
			{
				injectionPoint = new MethodInjectionPoint(node, this);
				injectionPoints.push(injectionPoint);
			}*/
			
			//get post construct methods
			/*var postConstructMethodPoints : Array = [];
			for each (node in description.factory.method.metadata.(@name == 'PostConstruct'))
			{
				injectionPoint = new PostConstructInjectionPoint(node, this);
				postConstructMethodPoints.push(injectionPoint);
			}
			if (postConstructMethodPoints.length > 0)
			{
				postConstructMethodPoints.sortOn("order", Array.NUMERIC);
				injectionPoints.push.apply(injectionPoints, postConstructMethodPoints);
			}*/

			var injecteeDescription : InjecteeDescription =
					new InjecteeDescription(ctorInjectionPoint, injectionPoints);

			COMPILE::SWF{
				m_injecteeDescriptions[clazz]  = injecteeDescription;
			}

			COMPILE::JS{
				m_injecteeDescriptions.set(clazz,injecteeDescription );
			}


			return injecteeDescription;
		}

		private function getConfigurationForRequest(
			clazz : Class, named : String, traverseAncestors : Boolean = true) : InjectionConfig
		{
			var requestName : String = getQualifiedClassName(clazz);
			var config:InjectionConfig = m_mappings[requestName + '#' + named];
			if(!config && traverseAncestors &&
				m_parentInjector && m_parentInjector.hasMapping(clazz, named))
			{
				config = getAncestorMapping(clazz, named);
			}
			return config;
		}
		
		private function createInjectionPointsFromConfigXML(description : TypeDefinition) : void
		{
			var node : XML;

			//@ttodo
			throw new Error('@todo createInjectionPointsFromConfigXML ')
			//first, clear out all "Inject" metadata, we want a clean slate to have the result 
			//work the same in the Flash IDE and MXMLC
			/*for each (node in description..metadata.(@name=='Inject' || @name=='PostConstruct'))
			{
				delete node.parent().metadata.(@name=='Inject' || @name=='PostConstruct')[0];
			}


			
			//now, we create the new injection points based on the given xml file
			var className:String = description.qualifiedName;
			for each (node in m_xmlMetadata.type.(@name == className).children())
			{
				var metaNode : XML = <metadata/>;
				if (node.name() == 'postconstruct')
				{
					metaNode.@name = 'PostConstruct';
					if (node.@order.length())
					{
						metaNode.appendChild(<arg key='order' value={node.@order}/>);
					}
				}
				else
				{
					metaNode.@name = 'Inject';
					if (node.@injectionname.length())
					{
						metaNode.appendChild(<arg key='name' value={node.@injectionname}/>);
					}
					for each (var arg : XML in node.arg)
					{
						metaNode.appendChild(<arg key='name' value={arg.@injectionname}/>);
					}
				}
				var typeNode : XML;
				if (node.name() == 'constructor')
				{
					typeNode = description.factory[0];
				}
				else
				{
					typeNode = description.factory.*.(attribute('name') == node.@name)[0];
					if (!typeNode)
					{
						throw new InjectorError('Error in XML configuration: Class "' + className +
							'" doesn\'t contain the instance member "' + node.@name + '"');
					}
				}
				typeNode.appendChild(metaNode);
			}*/
		}
		
		private function addParentInjectionPoints(description : TypeDefinition, injectionPoints : Array) : void
		{
			var ancestors:Array = description.baseClasses;
			if (!ancestors || !ancestors.length) return;
			var parentDefinition:TypeDefinition = TypeDefinition(ancestors[0]);
			if (!parentDefinition) return;

			/*var parentClassName : String = parentDefinition.qualifiedName;
			if (!parentClassName)
			{
				return;
			}
			var parentClass : Class = Class(getDefinitionByName(parentClassName));*/

			var parentClass : Class = parentDefinition.getClass();
			var parentDescription : InjecteeDescription;
			COMPILE::SWF{
				parentDescription = m_injecteeDescriptions[parentClass] || getInjectionPoints(parentClass);
			}

			COMPILE::JS{
				parentDescription = m_injecteeDescriptions.get(parentClass) || getInjectionPoints(parentClass);
			}

			var parentInjectionPoints : Array = parentDescription.injectionPoints;

			injectionPoints.push.apply(injectionPoints, parentInjectionPoints);
		}
	}
}

import org.swiftsuspenders.injectionpoints.InjectionPoint;

final class InjecteeDescription
{
	public var ctor : InjectionPoint;
	public var injectionPoints : Array;

	public function InjecteeDescription(ctor : InjectionPoint, injectionPoints : Array)
	{
		this.ctor = ctor;
		this.injectionPoints = injectionPoints;
	}
}