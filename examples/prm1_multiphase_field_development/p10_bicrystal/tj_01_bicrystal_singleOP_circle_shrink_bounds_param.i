# ------------------------------------------------------------------
# File: tj_01_bicrystal_singleOP_circle_shrink_bounds_param.i
# Purpose:
#   Parameterized two-grain single-order-parameter benchmark with bounds
#   based on the isotropic reduced form discussed from Steinbach Acta 2020.
#   Case: circular grain shrinkage in 2D.
#
# Notes:
#   1) phi1 is explicitly solved.
#   2) phi2 = 1 - phi1 is reconstructed by AuxKernel.
#   3) Bounds are added to keep phi1 in [0, 1].
#   4) This is a numerically bounded approximation, not a strict
#      variational-inequality implementation of the double-obstacle model.
# ------------------------------------------------------------------

my_filename = 'tj_01_bi_circle_shrink_bounds_default'
my_interval = 10

# mesh parameters
nx = 200
ny = 200
xmin = 0.0
xmax = 100.0
ymin = 0.0
ymax = 100.0

# initial condition parameters
xc = 50.0
yc = 50.0
r0 = 20.0
w0 = 2.0

# material parameters
sigma = 1.0
mobility = 1.0
int_width = 4.0

# time stepping parameters
dt0 = 0.0001
dtmax = 5.0
end_time = 150.0
optimal_iterations = 6

[GlobalParams]
  order = FIRST
  family = LAGRANGE
[]

[Mesh]
  type = GeneratedMesh
  dim = 2
  nx = ${nx}
  ny = ${ny}
  xmin = ${xmin}
  xmax = ${xmax}
  ymin = ${ymin}
  ymax = ${ymax}
  elem_type = QUAD4
[]

[Variables]
  [./phi1]
  [../]
[]

[AuxVariables]
  [./bounds_dummy]
    order = FIRST
    family = LAGRANGE
  [../]

  [./phi2]
    order = FIRST
    family = LAGRANGE
  [../]

  [./sum_phi]
    order = FIRST
    family = MONOMIAL
  [../]

  [./bnds]
    order = FIRST
    family = MONOMIAL
  [../]
[]

[Functions]
  [./phi1_init]
    type = ParsedFunction
    expression = '0.5*(1.0 - tanh((sqrt((x-xc)^2 + (y-yc)^2) - r0)/w0))'
    symbol_names = 'xc yc r0 w0'
    symbol_values = '${xc} ${yc} ${r0} ${w0}'
  [../]
[]

[ICs]
  [./phi1_ic]
    type = FunctionIC
    variable = phi1
    function = phi1_init
  [../]
[]

[Bounds]
  [./phi1_upper_bound]
    type = ConstantBounds
    variable = bounds_dummy
    bounded_variable = phi1
    bound_type = upper
    bound_value = 1.0
  [../]

  [./phi1_lower_bound]
    type = ConstantBounds
    variable = bounds_dummy
    bounded_variable = phi1
    bound_type = lower
    bound_value = 0.0
  [../]
[]

[Materials]
  [./tj2_mat]
    type = TJ2PhaseMaterial
    sigma = ${sigma}
    mobility = ${mobility}
    int_width = ${int_width}
  [../]
[]

[Kernels]
  [./time_phi1]
    type = TimeDerivative
    variable = phi1
  [../]

  [./ac_interface_phi1]
    type = TJ2PhaseACInterface
    variable = phi1
  [../]
[]

[AuxKernels]
  [./phi2_aux]
    type = ParsedAux
    variable = phi2
    expression = '1.0 - phi1'
    coupled_variables = 'phi1'
    execute_on = 'initial timestep_end'
  [../]

  [./sum_phi_aux]
    type = ParsedAux
    variable = sum_phi
    expression = 'phi1 + phi2'
    coupled_variables = 'phi1 phi2'
    execute_on = 'initial timestep_end'
  [../]

  [./bnds_aux]
    type = ParsedAux
    variable = bnds
    expression = 'phi1^2 + phi2^2'
    coupled_variables = 'phi1 phi2'
    execute_on = 'initial timestep_end'
  [../]
[]

[Postprocessors]
  [./phi1_integral]
    type = ElementIntegralVariablePostprocessor
    variable = phi1
    execute_on = 'initial timestep_end'
  [../]

  [./phi1_min]
    type = NodalExtremeValue
    variable = phi1
    value_type = min
    execute_on = 'initial timestep_end'
  [../]

  [./phi1_max]
    type = NodalExtremeValue
    variable = phi1
    value_type = max
    execute_on = 'initial timestep_end'
  [../]

  [./phi2_min]
    type = NodalExtremeValue
    variable = phi2
    value_type = min
    execute_on = 'initial timestep_end'
  [../]

  [./phi2_max]
    type = NodalExtremeValue
    variable = phi2
    value_type = max
    execute_on = 'initial timestep_end'
  [../]

  [./sum_phi_avg]
    type = ElementAverageValue
    variable = sum_phi
    execute_on = 'initial timestep_end'
  [../]
[]

[Executioner]
  type = Transient
  scheme = bdf2
  solve_type = NEWTON

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = ${dt0}
    optimal_iterations = ${optimal_iterations}
  []

  dtmax = ${dtmax}
  end_time = ${end_time}

  nl_rel_tol = 1e-10
  nl_abs_tol = 1e-10
  l_tol = 1e-12
  l_max_its = 100

  automatic_scaling = true
  petsc_options_iname = '-snes_type'
  petsc_options_value = 'vinewtonrsls'
[]

[Outputs]
  [./my_exodus]
    file_base = ./ex_${my_filename}/out_${my_filename}
    type = Nemesis
    time_step_interval = ${my_interval}
    additional_execute_on = 'FINAL'
  [../]
  [./my_csv]
    file_base = ./csv_${my_filename}
    type = CSV
  [../]
[]