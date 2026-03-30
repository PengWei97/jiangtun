#include "TJ2PhaseACInterface.h"

registerMooseObject("jiangtunApp", TJ2PhaseACInterface);

InputParameters
TJ2PhaseACInterface::validParams()
{
  InputParameters params = Kernel::validParams();
  params.addClassDescription(
      "Two-grain single-phase-field kernel: diffusion + obstacle/barrier term.");
  return params;
}

TJ2PhaseACInterface::TJ2PhaseACInterface(const InputParameters & parameters)
  : Kernel(parameters),
    _L_coef(getMaterialProperty<Real>("L_coef")),
    _K_coef(getMaterialProperty<Real>("K_coef"))
{
}

Real
TJ2PhaseACInterface::computeQpResidual()
{
  // Residual:
  // L * grad(test) · grad(u) - K * test * (u - 1/2)

  return _L_coef[_qp] * (_grad_test[_i][_qp] * _grad_u[_qp]) -
         _K_coef[_qp] * _test[_i][_qp] * (_u[_qp] - 0.5);
}

Real
TJ2PhaseACInterface::computeQpJacobian()
{
  // Jacobian:
  // L * grad(test) · grad(phi_j) - K * test * phi_j

  return _L_coef[_qp] * (_grad_test[_i][_qp] * _grad_phi[_j][_qp]) -
         _K_coef[_qp] * _test[_i][_qp] * _phi[_j][_qp];
}