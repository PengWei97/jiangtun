# ============================================================
# cht_closed_cavity_natural_convection_simple.i
#
# 2D closed cavity conjugate heat transfer (CHT)
# Solver: steady SIMPLE + linear finite volume
#
# Domain layout
#   - upper block : fluid cavity
#   - lower block : solid plate
#   - interface   : stitched fluid-solid boundary
#
# Physics included
#   - fluid: incompressible flow + energy equation
#   - buoyancy: Boussinesq approximation
#   - solid: heat conduction + localized volumetric heat source
#   - interface: Robin-Robin CHT coupling
#
# Thermal boundary model used in this case
#   - fluid top          : fixed cold temperature
#   - fluid left/right   : adiabatic
#   - solid left/right   : adiabatic
#   - solid bottom       : fixed temperature (NOT adiabatic)
#
# Notes
#   1) This is not a pure conduction case in the fluid because the energy
#      equation still contains advection and the momentum equations include
#      buoyancy.
#   2) With gravity + Boussinesq + internal heating, a non-zero recirculating
#      flow may appear. Therefore the velocity field should not be assumed to
#      converge to zero.
# ============================================================

# -----------------------------
# Geometry
# -----------------------------
Lx = 1.0
H_fluid = 1.0
H_solid = 0.20

nx = 80
ny_fluid = 80
ny_solid = 20

# -----------------------------
# Fluid properties
# -----------------------------
rho_f = 1.0
mu_f = 1.0e-3
k_fluid = 1.0e-2
cp_f = 1.0
beta_f = 3.33e-3
T_ref = 300.0

# -----------------------------
# Solid properties
# -----------------------------
k_solid = 5.0e-2

# -----------------------------
# Thermal boundary conditions
# -----------------------------
T_init = 298.15
T_top_cold = 200.0
T_bottom_solid = 0.0

# -----------------------------
# Interface coupling
# -----------------------------
h_fluid_side = 1.0
h_solid_side = 1.0

# -----------------------------
# Localized heater definition
# Heater centered at (0.5, -0.1)
# half-width  = 0.05
# half-height = 0.02
# -----------------------------
heater_xc = 0.5
heater_yc = -0.1
heater_half_width = 0.05
heater_half_height = 0.02
heater_qdot = 1.0e4

# -----------------------------
# Numerical options
# -----------------------------
advected_interp_method = 'upwind'
use_nonorthogonal_correction = false

[Mesh]
  [fluid_mesh]
    type = GeneratedMeshGenerator
    dim = 2
    nx = ${nx}
    ny = ${ny_fluid}
    xmin = 0.0
    xmax = ${Lx}
    ymin = 0.0
    ymax = ${H_fluid}
    subdomain_ids = '1'
    subdomain_name = 'fluid'
    boundary_name_prefix = 'fluid'
  []

  [solid_mesh]
    type = GeneratedMeshGenerator
    dim = 2
    nx = ${nx}
    ny = ${ny_solid}
    xmin = 0.0
    xmax = ${Lx}
    ymin = '-${H_solid}'
    ymax = 0.0
    subdomain_ids = '2'
    subdomain_name = 'solid'
    boundary_name_prefix = 'solid'
  []

  [stitched_mesh]
    type = StitchedMeshGenerator
    inputs = 'fluid_mesh solid_mesh'
    stitch_boundaries_pairs = 'fluid_bottom solid_top'
  []

  [fluid_solid_interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = stitched_mesh
    primary_block = fluid
    paired_block = solid
    new_boundary = interface
  []
[]

[Problem]
  linear_sys_names = 'u_system v_system pressure_system energy_system solid_energy_system'
  previous_nl_solution_required = true
[]

[Functions]
  [volumetric_heater]
    type = ParsedFunction
    expression = 'if(abs(x-${heater_xc})<${heater_half_width}, if(abs(y-${heater_yc})<${heater_half_height}, ${heater_qdot}, 0), 0)'
  []
[]

[UserObjects]
  [rhie_chow]
    type = RhieChowMassFlux
    block = fluid
    u = vel_x
    v = vel_y
    pressure = pressure
    rho = ${rho_f}
    p_diffusion_kernel = p_diffusion
  []
[]

[Variables]
  [vel_x]
    type = MooseLinearVariableFVReal
    solver_sys = u_system
    block = fluid
    initial_condition = 0.0
  []

  [vel_y]
    type = MooseLinearVariableFVReal
    solver_sys = v_system
    block = fluid
    initial_condition = 0.0
  []

  [pressure]
    type = MooseLinearVariableFVReal
    solver_sys = pressure_system
    block = fluid
    initial_condition = 0.0
  []

  [T_fluid]
    type = MooseLinearVariableFVReal
    solver_sys = energy_system
    block = fluid
    initial_condition = ${T_init}
  []

  [T_solid]
    type = MooseLinearVariableFVReal
    solver_sys = solid_energy_system
    block = solid
    initial_condition = ${T_init}
  []
[]

[LinearFVKernels]
  # ----------------------------------------------------------
  # Fluid momentum
  # ----------------------------------------------------------
  [u_momentum_flux]
    type = LinearWCNSFVMomentumFlux
    variable = vel_x
    block = fluid
    advected_interp_method = ${advected_interp_method}
    mu = ${mu_f}
    u = vel_x
    v = vel_y
    momentum_component = 'x'
    rhie_chow_user_object = 'rhie_chow'
    use_nonorthogonal_correction = ${use_nonorthogonal_correction}
  []

  [v_momentum_flux]
    type = LinearWCNSFVMomentumFlux
    variable = vel_y
    block = fluid
    advected_interp_method = ${advected_interp_method}
    mu = ${mu_f}
    u = vel_x
    v = vel_y
    momentum_component = 'y'
    rhie_chow_user_object = 'rhie_chow'
    use_nonorthogonal_correction = ${use_nonorthogonal_correction}
  []

  [u_pressure_grad]
    type = LinearFVMomentumPressure
    variable = vel_x
    block = fluid
    pressure = pressure
    momentum_component = 'x'
  []

  [v_pressure_grad]
    type = LinearFVMomentumPressure
    variable = vel_y
    block = fluid
    pressure = pressure
    momentum_component = 'y'
  []

  # [u_buoyancy]
  #   type = LinearFVMomentumBoussinesq
  #   variable = vel_x
  #   block = fluid
  #   rho = ${rho_f}
  #   gravity = '0 -9.81 0'
  #   alpha_name = ${beta_f}
  #   ref_temperature = ${T_ref}
  #   T_fluid = T_fluid
  #   momentum_component = 'x'
  # []

  [v_buoyancy]
    type = LinearFVMomentumBoussinesq
    variable = vel_y
    block = fluid
    rho = ${rho_f}
    gravity = '0 -9.81 0'
    alpha_name = ${beta_f}
    ref_temperature = ${T_ref}
    T_fluid = T_fluid
    momentum_component = 'y'
  []

  # ----------------------------------------------------------
  # SIMPLE pressure correction
  # ----------------------------------------------------------
  [p_diffusion]
    type = LinearFVAnisotropicDiffusion
    variable = pressure
    block = fluid
    diffusion_tensor = Ainv
    use_nonorthogonal_correction = ${use_nonorthogonal_correction}
  []

  [p_hbya_divergence]
    type = LinearFVDivergence
    variable = pressure
    block = fluid
    face_flux = HbyA
    force_boundary_execution = true
  []

  # ----------------------------------------------------------
  # Fluid energy
  # ----------------------------------------------------------
  [fluid_energy_diffusion]
    type = LinearFVDiffusion
    variable = T_fluid
    block = fluid
    diffusion_coeff = ${k_fluid}
    use_nonorthogonal_correction = ${use_nonorthogonal_correction}
  []

  [fluid_energy_advection]
    type = LinearFVEnergyAdvection
    variable = T_fluid
    advected_quantity = temperature
    cp = ${cp_f}
    advected_interp_method = ${advected_interp_method}
    rhie_chow_user_object = 'rhie_chow'
  []

  # ----------------------------------------------------------
  # Solid energy
  # ----------------------------------------------------------
  [solid_energy_diffusion]
    type = LinearFVDiffusion
    variable = T_solid
    block = solid
    diffusion_coeff = ${k_solid}
    use_nonorthogonal_correction = ${use_nonorthogonal_correction}
  []

  [solid_energy_source]
    type = LinearFVSource
    variable = T_solid
    block = solid
    source_density = volumetric_heater
  []
[]

[LinearFVBCs]
  # ----------------------------------------------------------
  # Fluid velocity: no-slip closed cavity walls
  # ----------------------------------------------------------
  [fluid_u_noslip]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'fluid_left fluid_right fluid_top interface'
    functor = 0.0
  []

  [fluid_v_noslip]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'fluid_left fluid_right fluid_top interface'
    functor = 0.0
  []

  # ----------------------------------------------------------
  # Pressure: zero-gradient + one pressure pin in Executioner
  # ----------------------------------------------------------
  [pressure_zero_gradient]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = pressure
    boundary = 'fluid_left fluid_right fluid_top interface'
    functor = 0.0
  []

  # ----------------------------------------------------------
  # Fluid thermal boundary conditions
  # ----------------------------------------------------------
  [fluid_top_temperature]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = T_fluid
    boundary = 'fluid_top'
    functor = ${T_top_cold}
  []

  [fluid_side_adiabatic]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_fluid
    boundary = 'fluid_left fluid_right'
    functor = 0.0
  []

  # ----------------------------------------------------------
  # Solid external thermal boundary conditions
  # ----------------------------------------------------------
  [solid_side_adiabatic]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_solid
    boundary = 'solid_left solid_right'
    functor = 0.0
  []

  [solid_bottom_temperature]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = T_solid
    boundary = 'solid_bottom'
    functor = ${T_bottom_solid}
  []

  # ----------------------------------------------------------
  # Fluid-solid interface (Robin-Robin CHT)
  # ----------------------------------------------------------
  [cht_fluid_side]
    type = LinearFVRobinCHTBC
    variable = T_fluid
    boundary = interface
    h = ${h_fluid_side}
    incoming_flux = heat_flux_to_fluid_interface
    surface_temperature = interface_temperature_solid_interface
    thermal_conductivity = ${k_fluid}
  []

  [cht_solid_side]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = interface
    h = ${h_solid_side}
    incoming_flux = heat_flux_to_solid_interface
    surface_temperature = interface_temperature_fluid_interface
    thermal_conductivity = ${k_solid}
  []
[]

[AuxVariables]
  [T]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[AuxKernels]
  [T_in_fluid]
    type = FunctorAux
    variable = T
    block = fluid
    functor = T_fluid
  []

  [T_in_solid]
    type = FunctorAux
    variable = T
    block = solid
    functor = T_solid
  []
[]

[Executioner]
  type = SIMPLE

  rhie_chow_user_object = 'rhie_chow'
  momentum_systems = 'u_system v_system'
  pressure_system = 'pressure_system'
  energy_system = 'energy_system'
  solid_energy_system = 'solid_energy_system'

  momentum_l_abs_tol = 1e-12
  pressure_l_abs_tol = 1e-12
  energy_l_abs_tol = 1e-12
  solid_energy_l_abs_tol = 1e-12

  momentum_l_tol = 0
  pressure_l_tol = 0
  energy_l_tol = 0
  solid_energy_l_tol = 0

  momentum_equation_relaxation = 0.8
  pressure_variable_relaxation = 0.3
  energy_equation_relaxation = 1.0

  energy_absolute_tolerance = 1e-10
  solid_energy_absolute_tolerance = 1e-10

  momentum_petsc_options_iname = '-pc_type -pc_hypre_type'
  momentum_petsc_options_value = 'hypre boomeramg'
  pressure_petsc_options_iname = '-pc_type -pc_hypre_type'
  pressure_petsc_options_value = 'hypre boomeramg'
  energy_petsc_options_iname = '-pc_type -pc_hypre_type'
  energy_petsc_options_value = 'hypre boomeramg'
  solid_energy_petsc_options_iname = '-pc_type -pc_hypre_type'
  solid_energy_petsc_options_value = 'hypre boomeramg'

  pin_pressure = true
  pressure_pin_value = 0.0
  pressure_pin_point = '0.5 0.5 0.0'

  cht_interfaces = 'interface'
  cht_solid_flux_relaxation = 1.0
  cht_fluid_flux_relaxation = 1.0
  cht_solid_temperature_relaxation = 1.0
  cht_fluid_temperature_relaxation = 1.0
  max_cht_fpi = 2

  num_iterations = 200
  print_fields = false
[]

[Outputs]
  exodus = true
  csv = true
[]
