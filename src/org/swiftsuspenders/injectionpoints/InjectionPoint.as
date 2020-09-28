/*
 * Copyright (c) 2009 the original author or authors
 * 
 * Permission is hereby granted to use, modify, and distribute this file 
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.swiftsuspenders.injectionpoints
{
	import org.swiftsuspenders.Injector;
	import org.apache.royale.reflection.DefinitionWithMetaData;

	public class InjectionPoint
	{
		/*******************************************************************************************
		*								public methods											   *
		*******************************************************************************************/
		public function InjectionPoint(def : DefinitionWithMetaData, injector : Injector)
		{
			initializeInjection(def);
		}
		
		public function applyInjection(target : Object, injector : Injector) : Object
		{
			return target;
		}


		/*******************************************************************************************
		*								protected methods										   *
		*******************************************************************************************/
		protected function initializeInjection(def : DefinitionWithMetaData) : void
		{
		}
	}
}