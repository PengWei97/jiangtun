#pragma once

#include "Kernel.h"

class TJ2PhaseACInterface : public Kernel
{
public:
  static InputParameters validParams();
  TJ2PhaseACInterface(const InputParameters & parameters);

protected:
  virtual Real computeQpResidual() override;
  virtual Real computeQpJacobian() override;

  /// material properties
  const MaterialProperty<Real> & _L_coef;
  const MaterialProperty<Real> & _K_coef;
};