#pragma once

#include "Material.h"

class TJ2PhaseMaterial : public Material
{
public:
  static InputParameters validParams();
  TJ2PhaseMaterial(const InputParameters & parameters);

protected:
  virtual void computeQpProperties() override;

  /// input parameters
  const Real _sigma;
  const Real _mobility;
  const Real _int_width;

  /// material properties
  MaterialProperty<Real> & _L_coef;
  MaterialProperty<Real> & _K_coef;
};