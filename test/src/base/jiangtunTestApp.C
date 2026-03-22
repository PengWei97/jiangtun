//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html
#include "jiangtunTestApp.h"
#include "jiangtunApp.h"
#include "Moose.h"
#include "AppFactory.h"
#include "MooseSyntax.h"

InputParameters
jiangtunTestApp::validParams()
{
  InputParameters params = jiangtunApp::validParams();
  params.set<bool>("use_legacy_material_output") = false;
  params.set<bool>("use_legacy_initial_residual_evaluation_behavior") = false;
  return params;
}

jiangtunTestApp::jiangtunTestApp(const InputParameters & parameters) : MooseApp(parameters)
{
  jiangtunTestApp::registerAll(
      _factory, _action_factory, _syntax, getParam<bool>("allow_test_objects"));
}

jiangtunTestApp::~jiangtunTestApp() {}

void
jiangtunTestApp::registerAll(Factory & f, ActionFactory & af, Syntax & s, bool use_test_objs)
{
  jiangtunApp::registerAll(f, af, s);
  if (use_test_objs)
  {
    Registry::registerObjectsTo(f, {"jiangtunTestApp"});
    Registry::registerActionsTo(af, {"jiangtunTestApp"});
  }
}

void
jiangtunTestApp::registerApps()
{
  registerApp(jiangtunApp);
  registerApp(jiangtunTestApp);
}

/***************************************************************************************************
 *********************** Dynamic Library Entry Points - DO NOT MODIFY ******************************
 **************************************************************************************************/
// External entry point for dynamic application loading
extern "C" void
jiangtunTestApp__registerAll(Factory & f, ActionFactory & af, Syntax & s)
{
  jiangtunTestApp::registerAll(f, af, s);
}
extern "C" void
jiangtunTestApp__registerApps()
{
  jiangtunTestApp::registerApps();
}
