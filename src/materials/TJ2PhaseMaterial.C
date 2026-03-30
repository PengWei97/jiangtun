#include "TJ2PhaseMaterial.h"
#include "Moose.h"

registerMooseObject("jiangtunApp", TJ2PhaseMaterial);

InputParameters
TJ2PhaseMaterial::validParams()
{
  InputParameters params = Material::validParams();
  params.addClassDescription("Material for two-grain single-phase-field model based on Steinbach "
                             "Acta 2020 isotropic reduction.");

  params.addRequiredParam<Real>("sigma", "Isotropic grain boundary energy sigma");
  params.addRequiredParam<Real>("mobility", "Isotropic grain boundary mobility m");
  params.addRequiredParam<Real>("int_width", "Diffuse interface width h");

  return params;
}

TJ2PhaseMaterial::TJ2PhaseMaterial(const InputParameters & parameters)
  : Material(parameters),
    _sigma(getParam<Real>("sigma")),
    _mobility(getParam<Real>("mobility")),
    _int_width(getParam<Real>("int_width")),
    _L_coef(declareProperty<Real>("L_coef")),
    _K_coef(declareProperty<Real>("K_coef"))
{
}

void
TJ2PhaseMaterial::computeQpProperties()
{
  const Real pi = libMesh::pi;

  _L_coef[_qp] = _mobility * _sigma;
  _K_coef[_qp] = pi * pi * _mobility * _sigma / (_int_width * _int_width);
}