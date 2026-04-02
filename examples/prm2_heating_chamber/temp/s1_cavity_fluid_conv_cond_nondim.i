# Minimal educational test for buoyancy-driven natural convection
# in a closed square cavity.
# Dimensionless / pedagogical setup:
# - top wall cold
# - bottom wall hot
# - left/right adiabatic
# - no-slip on all walls
# - no solid-fluid coupling in this step

base_name = 'step2_mesh80_pin'

mu = 0.1
rho = 1.0
advected_interp_method = 'average'
cp = 1.0
k = 0.5
alpha_b = 0.02
gravity = '0 -9.8 0'
ref_temperature = 0.0

Tbase = 0.05
A = 0.35
sigma = 0.18

[Mesh]
  [mesh]
    type = CartesianMeshGenerator
    dim = 2
    dx = '1.0'
    dy = '1.0'
    ix = '80'
    iy = '80'
  []
[]

[Problem]
  linear_sys_names = 'u_system v_system pressure_system energy_system'
  previous_nl_solution_required = true
[]

[UserObjects]
  [rc]
    type = RhieChowMassFlux
    u = vel_x
    v = vel_y
    pressure = pressure
    rho = ${rho}
    p_diffusion_kernel = p_diffusion
  []
[]

[Variables]
  [vel_x]
    type = MooseLinearVariableFVReal
    initial_condition = 0.0
    solver_sys = u_system
  []
  [vel_y]
    type = MooseLinearVariableFVReal
    solver_sys = v_system
    initial_condition = 0.0
  []
  [pressure]
    type = MooseLinearVariableFVReal
    solver_sys = pressure_system
    initial_condition = 0.0
  []
  [T]
    type = MooseLinearVariableFVReal
    solver_sys = energy_system
    initial_condition = 0.0
  []
[]

[LinearFVKernels]
  # ----------------------------------------------------------
  # Fluid momentum transient terms
  # rho * d(u)/dt
  # rho * d(v)/dt
  # ----------------------------------------------------------
  [u_time]
    type = LinearFVTimeDerivative
    variable = vel_x
    factor = ${rho}
  []
  [v_time]
    type = LinearFVTimeDerivative
    variable = vel_y
    factor = ${rho}
  []

  # ----------------------------------------------------------
  # Fluid momentum
  # ----------------------------------------------------------  
  [u_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_x
    advected_interp_method = ${advected_interp_method}
    mu = ${mu}
    u = vel_x
    v = vel_y
    momentum_component = 'x'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = false
  []
  [v_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_y
    advected_interp_method = ${advected_interp_method}
    mu = ${mu}
    u = vel_x
    v = vel_y
    momentum_component = 'y'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = false
  []


  [u_pressure]
    type = LinearFVMomentumPressure
    variable = vel_x
    pressure = pressure
    momentum_component = 'x'
  []
  [v_pressure]
    type = LinearFVMomentumPressure
    variable = vel_y
    pressure = pressure
    momentum_component = 'y'
  []

  [u_boussinesq]
    type = LinearFVMomentumBoussinesq
    variable = vel_x
    rho = ${rho}
    gravity = ${gravity}
    alpha_name = ${alpha_b}
    ref_temperature = ${ref_temperature}
    T_fluid = T
    momentum_component = 'x'
  []
  [v_boussinesq]
    type = LinearFVMomentumBoussinesq
    variable = vel_y
    rho = ${rho}
    gravity = ${gravity}
    alpha_name = ${alpha_b}
    ref_temperature = ${ref_temperature}
    T_fluid = T
    momentum_component = 'y'
  []

  # ----------------------------------------------------------
  # SIMPLE pressure correction
  # ----------------------------------------------------------
  [p_diffusion]
    type = LinearFVAnisotropicDiffusion
    variable = pressure
    diffusion_tensor = Ainv
    use_nonorthogonal_correction = false
  []
  [HbyA_divergence]
    type = LinearFVDivergence
    variable = pressure
    face_flux = HbyA
    force_boundary_execution = true
  []

  # ----------------------------------------------------------
  # Fluid energy transient term
  # rho * cp * dT/dt
  # ----------------------------------------------------------
  [h_time]
    type = LinearFVTimeDerivative
    variable = T
    factor = ${fparse rho*cp}
  []
  [h_advection]
    type = LinearFVEnergyAdvection
    variable = T
    advected_quantity = temperature
    cp = ${cp}
    advected_interp_method = ${advected_interp_method}
    rhie_chow_user_object = 'rc'
  []
  [conduction]
    type = LinearFVDiffusion
    variable = T
    diffusion_coeff = ${k}
    use_nonorthogonal_correction = false
  []
[]

[FunctorMaterials]
  [constant_functors]
    type = GenericFunctorMaterial
    prop_names = 'cp alpha_b'
    prop_values = '${cp} ${alpha_b}'
  []
[]

[LinearFVBCs]
  # ----------------------------------------------------------
  # Fluid velocity: no-slip on all external fluid walls and on the interface
  # ----------------------------------------------------------
  [fluid_u_noslip]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'left right top bottom'
    functor = 0.0
  []

  [fluid_v_noslip]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'left right top bottom'
    functor = 0.0
  []

  # ----------------------------------------------------------
  # Fluid thermal boundary conditions
  # ----------------------------------------------------------
  [fluid_top_temperature]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = T
    boundary = 'top'
    functor = 0.0
  []

  [fluid_side_adiabatic]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T
    boundary = 'left right'
    functor = 0.0
  []

  [fluid_bottom_hot]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = T
    boundary = 'bottom'
    functor = bottom_T_profile
  []
[]

[Functions]
  [bottom_T_profile]
    type = ParsedFunction
    expression = '${Tbase} + ${A}*exp(-((x-0.5)^2)/(2*${sigma}^2))'
  []
[]

[Executioner]
  type = PIMPLE
  momentum_l_abs_tol = 1e-10
  pressure_l_abs_tol = 1e-10
  energy_l_abs_tol = 1e-10

  momentum_l_tol = 0
  pressure_l_tol = 0
  energy_l_tol = 0

  rhie_chow_user_object = 'rc'
  momentum_systems = 'u_system v_system'
  pressure_system = 'pressure_system'
  energy_system = 'energy_system'

  momentum_equation_relaxation = 0.5
  pressure_variable_relaxation = 0.2
  energy_equation_relaxation = 0.7
  num_iterations = 100

  pressure_absolute_tolerance = 1e-8
  momentum_absolute_tolerance = 1e-8
  energy_absolute_tolerance = 1e-8

  pin_pressure =  true 
  pressure_pin_point = '0.5 1.0 0'
  pressure_pin_value = 0

  print_fields = false
  continue_on_max_its = false

  # end_time = 1.0
  num_steps = 100
  num_piso_iterations = 0

  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 5.0e-4
    optimal_iterations = 4
    iteration_window = 2
    growth_factor = 1.2
    cutback_factor = 0.5
  []
[]

[Postprocessors]
  [./dt]
    type = TimestepSize
  [../]
  [./run_time]
    type = PerfGraphData
    section_name = "Root"
    data_type = total
  [../]
[]

[Outputs]
  [./my_exodus]
    file_base = ./ex_${base_name}/out_${base_name}
    type = Exodus
    time_step_interval = 2
    additional_execute_on = 'FINAL'
  [../]
  csv = true
[]
