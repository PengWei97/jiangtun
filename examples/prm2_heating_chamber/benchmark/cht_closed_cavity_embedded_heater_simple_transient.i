# ============================================================
# cht_closed_cavity_embedded_heater_simple.i
#
# 2D closed cavity conjugate heat transfer (CHT)
# Solver: transient PIMPLE + linear finite volume
#
# Geometry / physical picture
#   - The whole cavity is initially fluid
#   - A bottom-centered rectangular subdomain is reassigned to solid
#   - The solid block acts as an embedded heater through volumetric heat generation
#   - Heat is transferred from the solid to the fluid through Robin-Robin CHT coupling
#   - The cavity is closed for flow (no-slip on all fluid walls and on the fluid-solid interface)
#
# External thermal boundaries
#   - top wall            : fixed cold temperature
#   - left/right walls    : adiabatic
#   - bottom fluid parts  : adiabatic
#   - bottom solid part   : adiabatic
#
# Physical objective
#   - To simulate conjugate heat transfer in a closed cavity containing an embedded solid heater
#   - Heat conduction occurs in both solid and fluid
#   - Natural convection develops in the fluid due to buoyancy
#   - The flow and temperature fields are fully coupled
#
# Notes
#   1) This version uses a single cavity mesh and carves out a solid block using
#      SubdomainBoundingBoxGenerator.
#   2) BreakBoundaryOnSubdomainGenerator is used only on the bottom boundary so
#      that the external bottom boundary can be split into:
#         bottom_to_fluid
#         bottom_to_solid
#   3) SideSetsBetweenSubdomainsGenerator creates the internal fluid-solid interface.
# ============================================================

my_filename = heat_s_1e3_transient
# -----------------------------
# Geometry
# -----------------------------
Lx = 1.0
Ly = 1.0

nx = 120
ny = 120

solid_w = 0.60
solid_h = 0.20
solid_xmin = ${fparse 0.5*(Lx-solid_w)}
solid_xmax = ${fparse 0.5*(Lx+solid_w)}

# -----------------------------
# Fluid properties
# -----------------------------
rho_f = 1.0
mu_f = 1.0e-3
k_fluid = 1.0e-2
cp_f = 1.0
beta_f = 3.33e-3

# volumetric heat capacity for fluid transient term: rho * cp
rho_cp_f = 1.0

# -----------------------------
# Solid properties
# -----------------------------
k_solid = 2.0e-1

# volumetric heat capacity for solid transient term
# please replace with a more physical value if needed
rho_cp_s = 1.0

# -----------------------------
# Thermal boundary conditions
# -----------------------------
T_init = 300.0
T_ref = 300.0
T_top_cold = 290.0

# -----------------------------
# Interface coupling
# Robin-Robin virtual heat transfer coefficients
# -----------------------------
h_fluid_side = 1.0
h_solid_side = 1.0

# -----------------------------
# Time stepping
# -----------------------------
dt = 1.0e-3
end_time = 100.0
num_piso_iterations = 3

# Localized heater definition
# Heater centered at (0.5, 0.1)
# half-width  = 0.05
# half-height = 0.02
# Heater region:
#   x in [0.45, 0.55]
#   y in [0.08, 0.12]
# -----------------------------
heater_xc = 0.5
heater_yc = 0.1
heater_half_width = 0.10
heater_half_height = 0.04
heater_qdot = 5.0e2

# -----------------------------
# Numerical options
# -----------------------------
advected_interp_method = 'upwind'
use_nonorthogonal_correction = false

[Functions]
  [volumetric_heater]
    type = ParsedFunction
    expression = 'if(abs(x-${heater_xc})<${heater_half_width}, if(abs(y-${heater_yc})<${heater_half_height}, ${heater_qdot}, 0), 0)'
  []
[]

[Mesh]
  # ------------------------------------------------------------
  # 1) Whole cavity: initially all fluid
  # ------------------------------------------------------------
  [base_mesh]
    type = GeneratedMeshGenerator
    dim = 2
    nx = ${nx}
    ny = ${ny}
    xmin = 0.0
    xmax = ${Lx}
    ymin = 0.0
    ymax = ${Ly}
    subdomain_ids = '1'
    subdomain_name = 'fluid'
  []

  # ------------------------------------------------------------
  # 2) Reassign the bottom-centered rectangular region to solid
  # ------------------------------------------------------------
  [solid_block]
    type = SubdomainBoundingBoxGenerator
    input = base_mesh
    block_id = 2
    block_name = solid
    bottom_left = '${solid_xmin} 0.0 0.0'
    top_right = '${solid_xmax} ${solid_h} 0.0'
    restricted_subdomains = 'fluid'
  []

  # ------------------------------------------------------------
  # 3) Split only the original bottom boundary by attached subdomain
  #    -> bottom_to_fluid
  #    -> bottom_to_solid
  # ------------------------------------------------------------
  [break_bottom_by_block]
    type = BreakBoundaryOnSubdomainGenerator
    input = solid_block
    boundaries = 'bottom'
  []

  # ------------------------------------------------------------
  # 4) Create the internal fluid-solid interface
  # ------------------------------------------------------------
  [fluid_solid_interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = break_bottom_by_block
    primary_block = fluid
    paired_block = solid
    new_boundary = interface
  []
[]

[Problem]
  linear_sys_names = 'u_system v_system pressure_system energy_system solid_energy_system'
  previous_nl_solution_required = true
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
  # Fluid momentum transient terms
  # rho * d(u)/dt
  # rho * d(v)/dt
  # ----------------------------------------------------------
  [u_momentum_time]
    type = LinearFVTimeDerivative
    variable = vel_x
    block = fluid
    factor = ${rho_f}
  []

  [v_momentum_time]
    type = LinearFVTimeDerivative
    variable = vel_y
    block = fluid
    factor = ${rho_f}
  []

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
  # Fluid energy transient term
  # rho * cp * dT/dt
  # ----------------------------------------------------------
  [fluid_energy_time]
    type = LinearFVTimeDerivative
    variable = T_fluid
    block = fluid
    factor = ${rho_cp_f}
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
    block = fluid
    advected_quantity = temperature
    cp = ${cp_f}
    advected_interp_method = ${advected_interp_method}
    rhie_chow_user_object = 'rhie_chow'
  []

  # ----------------------------------------------------------
  # Solid energy transient term
  # rho_cp_s * dT/dt
  # ----------------------------------------------------------
  [solid_energy_time]
    type = LinearFVTimeDerivative
    variable = T_solid
    block = solid
    factor = ${rho_cp_s}
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
  # Fluid velocity: no-slip on all external fluid walls and on the interface
  # ----------------------------------------------------------
  [fluid_u_noslip]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'left right top bottom_to_fluid interface'
    functor = 0.0
  []

  [fluid_v_noslip]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'left right top bottom_to_fluid interface'
    functor = 0.0
  []

  # ----------------------------------------------------------
  # Pressure: zero-gradient + one pressure pin in Executioner
  # ----------------------------------------------------------
  [pressure_zero_gradient]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = pressure
    boundary = 'left right top bottom_to_fluid interface'
    functor = 0.0
  []

  # ----------------------------------------------------------
  # Fluid thermal boundary conditions
  # ----------------------------------------------------------
  [fluid_top_temperature]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = T_fluid
    boundary = 'top'
    functor = ${T_top_cold}
  []

  [fluid_side_adiabatic]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_fluid
    boundary = 'left right'
    functor = 0.0
  []

  [fluid_bottom_adiabatic]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_fluid
    boundary = 'bottom_to_fluid'
    functor = 0.0
  []

  # ----------------------------------------------------------
  # Solid external thermal boundary condition (bottom only)
  # ----------------------------------------------------------
  [solid_bottom_adiabatic]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_solid
    boundary = 'bottom_to_solid'
    functor = 0.0
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
  type = PIMPLE

  rhie_chow_user_object = 'rhie_chow'
  momentum_systems = 'u_system v_system'
  pressure_system = 'pressure_system'
  energy_system = 'energy_system'
  solid_energy_system = 'solid_energy_system'

  scheme = implicit-euler
  # dt = ${dt}
  end_time = ${end_time}
  num_piso_iterations = ${num_piso_iterations}

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = ${dt}
    optimal_iterations = 4
    iteration_window = 2
    growth_factor = 1.2
    cutback_factor = 0.5
  []

  momentum_l_abs_tol = 1e-12
  pressure_l_abs_tol = 1e-12
  energy_l_abs_tol = 1e-12
  solid_energy_l_abs_tol = 1e-12

  momentum_l_tol = 0
  pressure_l_tol = 0
  energy_l_tol = 0
  solid_energy_l_tol = 0

  momentum_equation_relaxation = 0.7
  pressure_variable_relaxation = 0.3
  energy_equation_relaxation = 0.8

  momentum_absolute_tolerance = 1e-10
  pressure_absolute_tolerance = 1e-10
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
  pressure_pin_point = '0.5 0.9 0.0'

  cht_interfaces = 'interface'
  cht_heat_flux_tolerance = 1e-6
  cht_solid_flux_relaxation = 0.5
  cht_fluid_flux_relaxation = 0.5
  cht_solid_temperature_relaxation = 0.5
  cht_fluid_temperature_relaxation = 0.5
  max_cht_fpi = 2

  continue_on_max_its = true
  num_iterations = 80
  print_fields = false
[]

[Outputs]
  [./my_exodus]
    file_base = ./ex_${my_filename}/out_${my_filename}
    type = Exodus
    time_step_interval = 10
    additional_execute_on = 'FINAL'
  [../]
  csv = true
[]
