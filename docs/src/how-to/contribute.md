# [Contribute to EnergyModelsBase](@id how_to-con)

Contributing to `EnergyModelsBase` can be achieved in several different ways.

## [Create new extensions](@id how_to-con-ext)

The main focus of `EnergyModelsBase` is to provide an easily extensible energy system optimization modelling framework.
Hence, a first approach to contributing to `EnergyModelsBase` is to create a new package with, *e.g.*, the introduction of new node descriptions.

This is explained in [_How to create a new node_](@ref how_to-create_node).

!!! tip
    If you are uncertain how you could incorporate new nodal descriptions, take a look at [`EnergyModelsRenewableProducers`](https://github.com/EnergyModelsX/EnergyModelsRenewableProducers.jl).
    The package is maintained by the developers of `EnergyModelsBase`.
    Hence, it provides you with ideas on how we think it is best to develop new node descriptions.

## [File a bug report](@id how_to-con-bug_rep)

Another approach to contributing to `EnergyModelsBase` is through filing a bug report as an _[issue](https://github.com/EnergyModelsX/EnergyModelsBase.jl/issues/new)_ when unexpected behaviour is occuring.

When filing a bug report, please follow the following guidelines:

1. Be certain that the bug is a bug and originating in `EnergyModelsbase`:
    - If the problem is within the results of the optimization problem, please check first that the nodes are correctly linked with each other.
      Frequently, missing links (or wrongly defined links) restrict the transport of energy/mass.
      If you are certain that all links are set correctly, it is most likely a bug in `EnergyModelsBase` and should be reported.
    - If the problem occurs in model construction, it is most likely a bug in `EnergyModelsBase` and should be reported.
    - If the problem is only appearing for specific solvers, it is most likely not a bug in `EnergyModelsBase`, but instead a problem of the solver wrapper for `MathOptInterface`. In this case, please contact the developers of the corresponding solver wrapper.
2. Label the issue as bug, and
3. Provide a minimum working example of a case in which the bug occurs.

!!! note
    We are aware that certain design choices within `EnergyModelsBase` can lead to method ambiguities.
    Our aim is to extend the documentation to improve the description on how to best extend the base functionality as well as which caveats can occur.

    In order to improve the code, we welcome any reports of potential method ambiguities to help us improving the structure of the framework.

## [Feature requests](@id how_to-feat_req)

Although `EnergyModelsBase` was designed with the aim of flexibility, it sometimes still requires additional features to account for potential extensions.
Feature requests can be achieved through two approaches:

1. Create an issue describing the aim of the feature request and
2. Incorporate the feature request through a fork of the repository.

!!! note
    `EnergyModelsBase` should not include everything.

    The aim of the framework is to be lightweight and extendable by the user.
    Hence, feature requests should only include basic requirements for the core structure, and not, *e.g.*, the description of new technologies.
    These should be developed outside of `EnergyModelsBase`.

### [Create an Issue](@id how_to-feat_req-issue)

Creating a new _[issue](https://github.com/EnergyModelsX/EnergyModelsBase.jl/issues/new) for a feature request is our standard approach for extending `EnergyModelsBase`.
Due to the extendibility of `EnergyModelsBase`, it is not necessarily straight forward to understand how to best incorporate required features into the framework without breaking other packages.

When creating a new issue as feature request, please follow the the following guidelines.

1. **Reason for the feature**: Please describe the reasoning for the feature request. What functionality do you require in the core structure of `EnergyModelsBase`?
2. **Required outcome**: What should be the outcome when including the feature and what should be the minimum requirements of the outcome?
3. **Potential solutions**: Describe alternatives you consider. This step is not necessarily required, but can be helpful for identifying potential solutions.

### [Incorporating the feature requests through a fork](@id how_to-feat_req-fork)

!!! note
    The approach used for providing code is based on the excellent description of the [JuMP](https://jump.dev/JuMP.jl/stable/developers/contributing/#Contribute-code-to-JuMP) package.
    We essentially follow the same approach with minor changes.

If you would like to work directly in `EnergyModelsBase`, you can also incorporate your changes directly.
In this case, it is beneficial to follow the outlined steps:

#### [Step 1: Create an issue](@id how_to-feat_req-fork-step_1)

Even if you plan to incorporate the code directly, we advise you to first follow the steps outlined in *[Create an Issue](@ref how_to-feat_req-issue)*.
This way, it is possible for us to comment on the solution approach(es) and assess potential problems with the other core packages of the `EnergyModelsX` framework.

Through creating an issue first, it is possible for us to comment directly on the proposed changes and assess, whether we consider the proposed changes to follow the philosophy of the framework.

#### [Step 2: Create a fork of `EnergyModelsBase`](@id how_to-feat_req-fork-step_2)

Contributiing code to `EnergyModelsBase` should follow the standard approach by creating a fork of the repository.
All work on the code should occur within the fork.

#### [Step 3: Checkout a new branch in your local fork](@id how_to-feat_req-fork-step_3)

It is in general preferable to work on a separate branch when developing new components.

#### [Step 4: Make changes to the code base](@id how_to-feat_req-fork-step_4)

Incorporate your changes in your new branch.
The changes should be commented to understand the thought process behind them.
In addition, please provide new tests for the added functionality and be certain that the tests run.
The tests should be based on a minimum working example.

Some existing tests may potentially require changes when incorporating new features (especially within the test set `General tests`).
In this case, it is ok that they are failing and we will comment on the required changes in the pull request.

!!! tip
    It is in our experience easiest to use the package [`TestEnv`](https://github.com/JuliaTesting/TestEnv.jl) for testing the complete package.

It is not necessary to provide changes directly in the documentation.
It can be easier to include these changes after the pull request is accepted in principal.
It is however a requirement to update the [`NEWS.md`](https://github.com/EnergyModelsX/EnergyModelsBase.jl/blob/main/NEWS.md) file under a new subheading titled "Unversioned".

!!! note
    Currently, we have not written a style guide for the framework.
    We follow in general the conventions of the _[Blue style guide](https://github.com/JuliaDiff/BlueStyle)_ with minor modifications.

    `@constraint` macros are not following the style guide, as we personally consider the design more difficult to read.
    Please follow in that respect the used style within the package.

#### [Step 5: Create a pull request](@id how_to-feat_req-fork-step_5)

Once you are satisified with your changes, create a pull request towards the main branch of the `EnergyModelsBase` repository.
We will internally assign the relevant person to the pull request.

You may receive quite a few comments with respect to the incorporation and how it may potentially affect other parts of the code.
Please remaing patient as it may take potentially some time before we can respond to the changes, although we try to answer as fast as possible.
