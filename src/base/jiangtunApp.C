#include "jiangtunApp.h"
#include "Moose.h"
#include "AppFactory.h"
#include "ModulesApp.h"
#include "MooseSyntax.h"

InputParameters
jiangtunApp::validParams()
{
  InputParameters params = MooseApp::validParams();
  params.set<bool>("use_legacy_material_output") = false;
  params.set<bool>("use_legacy_initial_residual_evaluation_behavior") = false;
  return params;
}

jiangtunApp::jiangtunApp(const InputParameters & parameters) : MooseApp(parameters)
{
  jiangtunApp::registerAll(_factory, _action_factory, _syntax);
}

jiangtunApp::~jiangtunApp() {}

void
jiangtunApp::registerAll(Factory & f, ActionFactory & af, Syntax & syntax)
{
  ModulesApp::registerAllObjects<jiangtunApp>(f, af, syntax);
  Registry::registerObjectsTo(f, {"jiangtunApp"});
  Registry::registerActionsTo(af, {"jiangtunApp"});

  /* register custom execute flags, action syntax, etc. here */
}

void
jiangtunApp::registerApps()
{
  registerApp(jiangtunApp);
}

/***************************************************************************************************
 *********************** Dynamic Library Entry Points - DO NOT MODIFY ******************************
 **************************************************************************************************/
extern "C" void
jiangtunApp__registerAll(Factory & f, ActionFactory & af, Syntax & s)
{
  jiangtunApp::registerAll(f, af, s);
}
extern "C" void
jiangtunApp__registerApps()
{
  jiangtunApp::registerApps();
}
