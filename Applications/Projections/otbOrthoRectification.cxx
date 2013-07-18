/*=========================================================================

 Program:   ORFEO Toolbox
 Language:  C++
 Date:      $Date$
 Version:   $Revision$


 Copyright (c) Centre National d'Etudes Spatiales. All rights reserved.
 See OTBCopyright.txt for details.


 This software is distributed WITHOUT ANY WARRANTY; without even
 the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.  See the above copyright notices for more information.

 =========================================================================*/
#include "otbWrapperApplication.h"
#include "otbWrapperApplicationFactory.h"
#include "otbWrapperNumericalParameter.h"

#include "otbImageToGenericRSOutputParameters.h"
#include "otbGenericRSResampleImageFilter.h"

#include "itkLinearInterpolateImageFunction.h"
#include "otbBCOInterpolateImageFunction.h"
#include "itkNearestNeighborInterpolateImageFunction.h"

// MapProjection handler
#include "otbWrapperMapProjectionParametersHandler.h"

// Elevation handler
#include "otbWrapperElevationParametersHandler.h"

#include "otbMacro.h"

namespace otb
{


enum
{
  Interpolator_BCO,
  Interpolator_NNeighbor,
  Interpolator_Linear
};

enum
{
  Mode_UserDefined,
  Mode_AutomaticSize,
  Mode_AutomaticSpacing,
  Mode_OutputROI,
  Mode_OrthoFit
};

namespace Wrapper
{

class OrthoRectification : public Application
{
public:
/** Standard class typedefs. */
  typedef OrthoRectification            Self;
  typedef Application                   Superclass;
  typedef itk::SmartPointer<Self>       Pointer;
  typedef itk::SmartPointer<const Self> ConstPointer;

  /** Standard macro */
  itkNewMacro(Self);

  itkTypeMacro(OrthoRectification, otb::Application);

  /** Generic Remote Sensor Resampler */
  typedef otb::GenericRSResampleImageFilter<FloatVectorImageType,
                                            FloatVectorImageType>       ResampleFilterType;

  /** Interpolators typedefs*/
  typedef itk::LinearInterpolateImageFunction<FloatVectorImageType,
                                              double>              LinearInterpolationType;
  typedef itk::NearestNeighborInterpolateImageFunction<FloatVectorImageType,
                                                       double>     NearestNeighborInterpolationType;
  typedef otb::BCOInterpolateImageFunction<FloatVectorImageType>   BCOInterpolationType;

private:
  void DoInit()
  {
    SetName("OrthoRectification");
    std::ostringstream oss;
    oss << "This application allows to ortho-rectify optical images from supported sensors." << std::endl;
    SetDescription(oss.str());
    // Documentation
    SetDocName("Ortho-rectification");
    oss.str("");
    oss<<"An inverse sensor model is built from the input image metadata to convert geographical to raw geometry coordinates. ";
    oss<<"This inverse sensor model is then combined with the chosen map projection to build a global coordinate mapping grid. Last, this grid is used to resample using the chosen interpolation algorithm. ";
    oss<<"A Digital Elevation Model can be specified to account for terrain deformations. "<<std::endl;
    oss<<"In case of SPOT5 images, the sensor model can be approximated by an RPC model in order to speed-up computation.";
    SetDocLongDescription(oss.str());
    SetDocLimitations("Supported sensors are Pleiades, SPOT5 (TIF format), Ikonos, Quickbird, Worldview2, GeoEye.");
    SetDocAuthors("OTB-Team");
    SetDocSeeAlso("Ortho-rectification chapter from the OTB Software Guide");

    AddDocTag(Tags::Geometry);

    // Set the parameters
    AddParameter(ParameterType_Group,"io","Input and output data");
    SetParameterDescription("io","This group of parameters allows to set the input and output images.");
    AddParameter(ParameterType_InputImage, "io.in", "Input Image");
    SetParameterDescription("io.in","The input image to ortho-rectify");
    AddParameter(ParameterType_OutputImage, "io.out", "Output Image");
    SetParameterDescription("io.out","The ortho-rectified output image");

    // Build the Output Map Projection
    MapProjectionParametersHandler::AddMapProjectionParameters(this, "map");

    // Add the output paramters in a group
    AddParameter(ParameterType_Group, "outputs", "Output Image Grid");
    SetParameterDescription("outputs","This group of parameters allows to define the grid on which the input image will be resampled.");

    // UserDefined values
    AddParameter(ParameterType_Choice, "outputs.mode", "Parameters estimation modes");
    AddChoice("outputs.mode.auto", "User Defined");
    SetParameterDescription("outputs.mode.auto","This mode allows you to fully modify default values.");
    AddChoice("outputs.mode.autosize", "Automatic Size from Spacing");
    SetParameterDescription("outputs.mode.autosize","This mode allows you to automatically compute the optimal image size from given spacing (pixel size) values");
    AddChoice("outputs.mode.autospacing", "Automatic Spacing from Size");
    SetParameterDescription("outputs.mode.autospacing","This mode allows you to automatically compute the optimal image spacing (pixel size) from the given size");
    AddChoice("outputs.mode.outputroi", "Automatic Size from Spacing and output corners");
    SetParameterDescription("outputs.mode.outputroi","This mode allows you to automatically compute the optimal image size from spacing (pixel size) and output corners");
    AddChoice("outputs.mode.orthofit", "Fit to ortho");
    SetParameterDescription("outputs.mode.orthofit", "Fit the size, origin and spacing to an existing ortho image (uses the value of outputs.ortho)");

    // Upper left point coordinates
    AddParameter(ParameterType_Float, "outputs.ulx", "Upper Left X");
    SetParameterDescription("outputs.ulx","Cartographic X coordinate of upper-left corner (meters for cartographic projections, degrees for geographic ones)");

    AddParameter(ParameterType_Float, "outputs.uly", "Upper Left Y");
    SetParameterDescription("outputs.uly","Cartographic Y coordinate of the upper-left corner (meters for cartographic projections, degrees for geographic ones)");

    // Size of the output image
    AddParameter(ParameterType_Int, "outputs.sizex", "Size X");
    SetParameterDescription("outputs.sizex","Size of projected image along X (in pixels)");

    AddParameter(ParameterType_Int, "outputs.sizey", "Size Y");
    SetParameterDescription("outputs.sizey","Size of projected image along Y (in pixels)");

    // Spacing of the output image
    AddParameter(ParameterType_Float, "outputs.spacingx", "Pixel Size X");
    SetParameterDescription("outputs.spacingx","Size of each pixel along X axis (meters for cartographic projections, degrees for geographic ones)");


    AddParameter(ParameterType_Float, "outputs.spacingy", "Pixel Size Y");
    SetParameterDescription("outputs.spacingy","Size of each pixel along Y axis (meters for cartographic projections, degrees for geographic ones)");

    // Lower right point coordinates
    AddParameter(ParameterType_Float, "outputs.lrx", "Lower right X");
    SetParameterDescription("outputs.lrx","Cartographic X coordinate of the lower-right corner (meters for cartographic projections, degrees for geographic ones)");

    AddParameter(ParameterType_Float, "outputs.lry", "Lower right Y");
    SetParameterDescription("outputs.lry","Cartographic Y coordinate of the lower-right corner (meters for cartographic projections, degrees for geographic ones)");

    // Existing ortho image that can be used to compute size, origin and spacing of the output
    AddParameter(ParameterType_InputImage, "outputs.ortho", "Model ortho-image");
    SetParameterDescription("outputs.ortho","A model ortho-image that can be used to compute size, origin and spacing of the output");

    // Setup parameters for initial UserDefined mode
    DisableParameter("outputs.lrx");
    DisableParameter("outputs.lry");
    DisableParameter("outputs.ortho");
    MandatoryOff("outputs.lrx");
    MandatoryOff("outputs.lry");
    MandatoryOff("outputs.ortho");

    AddParameter(ParameterType_Empty,"outputs.isotropic","Force isotropic spacing by default");
    std::ostringstream isotropOss;
    isotropOss << "Default spacing (pixel size) values are estimated from the sensor modeling of the image. It can therefore result in a non-isotropic spacing. ";
    isotropOss << "This option allows you to force default values to be isotropic (in this case, the minimum of spacing in both direction is applied. ";
    isotropOss << "Values overriden by user are not affected by this option.";
    SetParameterDescription("outputs.isotropic", isotropOss.str());
    EnableParameter("outputs.isotropic");

    AddParameter(ParameterType_Float, "outputs.default", "Default pixel value");
    SetParameterDescription("outputs.default","Default value to write when outside of input image.");
    SetDefaultParameterFloat("outputs.default",0.);
    MandatoryOff("outputs.default");

    // Elevation
    ElevationParametersHandler::AddElevationParameters(this, "elev");

    // Interpolators
    AddParameter(ParameterType_Choice,   "interpolator", "Interpolation");
    AddChoice("interpolator.bco",    "Bicubic interpolation");
    AddParameter(ParameterType_Radius, "interpolator.bco.radius", "Radius for bicubic interpolation");
    SetParameterDescription("interpolator.bco.radius","This parameter allows to control the size of the bicubic interpolation filter. If the target pixel size is higher than the input pixel size, increasing this parameter will reduce aliasing artefacts.");
    SetParameterDescription("interpolator","This group of parameters allows to define how the input image will be interpolated during resampling.");
    AddChoice("interpolator.nn",     "Nearest Neighbor interpolation");
    SetParameterDescription("interpolator.nn","Nearest neighbor interpolation leads to poor image quality, but it is very fast.");
    AddChoice("interpolator.linear", "Linear interpolation");
    SetParameterDescription("interpolator.linear","Linear interpolation leads to average image quality but is quite fast");
    SetDefaultParameterInt("interpolator.bco.radius", 2);
    AddParameter(ParameterType_Group,"opt","Speed optimization parameters");
    SetParameterDescription("opt","This group of parameters allows to optimize processing time.");

    // Estimate a RPC model (for spot image for instance)
    AddParameter(ParameterType_Int, "opt.rpc", "RPC modeling (points per axis)");
    SetDefaultParameterInt("opt.rpc", 10);
    SetParameterDescription("opt.rpc","Enabling RPC modeling allows to speed-up SPOT5 ortho-rectification. Value is the number of control points per axis for RPC estimation");
    DisableParameter("opt.rpc");
    MandatoryOff("opt.rpc");

    // RAM available
    AddRAMParameter("opt.ram");
    SetParameterDescription("opt.ram","This allows to set the maximum amount of RAM available for processing. As the writing task is time consuming, it is better to write large pieces of data, which can be achieved by increasing this parameter (pay attention to your system capabilities)");

    // Deformation Field Spacing
    AddParameter(ParameterType_Float, "opt.gridspacing", "Resampling grid spacing");
    SetDefaultParameterFloat("opt.gridspacing", 4.);
    SetParameterDescription("opt.gridspacing", "Resampling is done according to a coordinate mapping grid, whose pixel size is set by this parameter. The closer to the output spacing this parameter is, the more precise will be the ortho-rectified image, but increasing this parameter allows to reduce processing time.");
    MandatoryOff("opt.gridspacing");

    // Doc example parameter settings
    SetDocExampleParameterValue("io.in", "QB_TOULOUSE_MUL_Extract_500_500.tif");
    SetDocExampleParameterValue("io.out","QB_Toulouse_ortho.tif");
  }

  void DoUpdateParameters()
  {
    if (HasValue("io.in"))
      {
      // input image
      FloatVectorImageType::Pointer inImage = GetParameterImage("io.in");

      // Update the UTM zone params
      MapProjectionParametersHandler::InitializeUTMParameters(this, "io.in", "map");

      // Get the output projection Ref
      m_OutputProjectionRef = MapProjectionParametersHandler::GetProjectionRefFromChoice(this, "map");

      // Compute the output image spacing and size
      typedef otb::ImageToGenericRSOutputParameters<FloatVectorImageType> OutputParametersEstimatorType;
      OutputParametersEstimatorType::Pointer genericRSEstimator = OutputParametersEstimatorType::New();

      if(IsParameterEnabled("outputs.isotropic"))
        {
        genericRSEstimator->EstimateIsotropicSpacingOn();
        }
      else
        {
        genericRSEstimator->EstimateIsotropicSpacingOff();
        }

      genericRSEstimator->SetInput(inImage);
      genericRSEstimator->SetOutputProjectionRef(m_OutputProjectionRef);
      genericRSEstimator->Compute();

      // Fill the Gui with the computed parameters
      if (!HasUserValue("outputs.ulx"))
        {
        SetParameterFloat("outputs.ulx", genericRSEstimator->GetOutputOrigin()[0]);
        }

      if (!HasUserValue("outputs.uly"))
        SetParameterFloat("outputs.uly", genericRSEstimator->GetOutputOrigin()[1]);

      if (!HasUserValue("outputs.sizex"))
        SetParameterInt("outputs.sizex", genericRSEstimator->GetOutputSize()[0]);

      if (!HasUserValue("outputs.sizey"))
        SetParameterInt("outputs.sizey", genericRSEstimator->GetOutputSize()[1]);

      if (!HasUserValue("outputs.spacingx"))
        SetParameterFloat("outputs.spacingx", genericRSEstimator->GetOutputSpacing()[0]);

      if (!HasUserValue("outputs.spacingy"))
        SetParameterFloat("outputs.spacingy", genericRSEstimator->GetOutputSpacing()[1]);

      if (!HasUserValue("outputs.lrx"))
       SetParameterFloat("outputs.lrx", GetParameterFloat("outputs.ulx") + GetParameterFloat("outputs.spacingx") * static_cast<double>(GetParameterInt("outputs.sizex")));

      if (!HasUserValue("outputs.lry"))
       SetParameterFloat("outputs.lry", GetParameterFloat("outputs.uly") + GetParameterFloat("outputs.spacingy") * static_cast<double>(GetParameterInt("outputs.sizey")));

      // Handle the spacing and size field following the mode
      // choosed by the user
      switch (GetParameterInt("outputs.mode") )
        {
        case Mode_UserDefined:
        {
        // Automatic set to off except lower right coordinates
        AutomaticValueOff("outputs.ulx");
        AutomaticValueOff("outputs.uly");
        AutomaticValueOff("outputs.sizex");
        AutomaticValueOff("outputs.sizey");
        AutomaticValueOff("outputs.spacingx");
        AutomaticValueOff("outputs.spacingy");
        AutomaticValueOn("outputs.lrx");
        AutomaticValueOn("outputs.lry");

        // Enable all the parameters except lower right coordinates
        EnableParameter("outputs.ulx");
        EnableParameter("outputs.uly");
        EnableParameter("outputs.spacingx");
        EnableParameter("outputs.spacingy");
        EnableParameter("outputs.sizex");
        EnableParameter("outputs.sizey");
        DisableParameter("outputs.lrx");
        DisableParameter("outputs.lry");
        DisableParameter("outputs.ortho");

        // Make all the parameters in this mode mandatory except lower right coordinates
        MandatoryOn("outputs.ulx");
        MandatoryOn("outputs.uly");
        MandatoryOn("outputs.spacingx");
        MandatoryOn("outputs.spacingy");
        MandatoryOn("outputs.sizex");
        MandatoryOn("outputs.sizey");
        MandatoryOff("outputs.lrx");
        MandatoryOff("outputs.lry");
        MandatoryOff("outputs.ortho");

        // Update lower right
        SetParameterFloat("outputs.lrx", GetParameterFloat("outputs.ulx") + GetParameterFloat("outputs.spacingx") * static_cast<double>(GetParameterInt("outputs.sizex")));
        SetParameterFloat("outputs.lry", GetParameterFloat("outputs.uly") + GetParameterFloat("outputs.spacingy") * static_cast<double>(GetParameterInt("outputs.sizey")));
        }
        break;
        case Mode_AutomaticSize:
        {
        // Disable the size fields
        DisableParameter("outputs.ulx");
        DisableParameter("outputs.uly");
        DisableParameter("outputs.sizex");
        DisableParameter("outputs.sizey");
        EnableParameter("outputs.spacingx");
        EnableParameter("outputs.spacingy");
        DisableParameter("outputs.lrx");
        DisableParameter("outputs.lry");
        DisableParameter("outputs.ortho");

        // Update the automatic value mode of each filed
        AutomaticValueOn("outputs.ulx");
        AutomaticValueOn("outputs.uly");
        AutomaticValueOn("outputs.sizex");
        AutomaticValueOn("outputs.sizey");
        AutomaticValueOff("outputs.spacingx");
        AutomaticValueOff("outputs.spacingy");
        AutomaticValueOn("outputs.lrx");
        AutomaticValueOn("outputs.lry");

        // Adapat the status of the param to this mode
        MandatoryOff("outputs.ulx");
        MandatoryOff("outputs.uly");
        MandatoryOn("outputs.spacingx");
        MandatoryOn("outputs.spacingy");
        MandatoryOff("outputs.sizex");
        MandatoryOff("outputs.sizey");
        MandatoryOff("outputs.lrx");
        MandatoryOff("outputs.lry");
        MandatoryOff("outputs.ortho");

        ResampleFilterType::SpacingType spacing;
        spacing[0] = GetParameterFloat("outputs.spacingx");
        spacing[1] = GetParameterFloat("outputs.spacingy");

        genericRSEstimator->ForceSpacingTo(spacing);
        genericRSEstimator->Compute();

        // Set the  processed size relative to this forced spacing
        SetParameterInt("outputs.sizex", genericRSEstimator->GetOutputSize()[0]);
        SetParameterInt("outputs.sizey", genericRSEstimator->GetOutputSize()[1]);

        // Reset Origin to default
        SetParameterFloat("outputs.ulx", genericRSEstimator->GetOutputOrigin()[0]);
        SetParameterFloat("outputs.uly", genericRSEstimator->GetOutputOrigin()[1]);

        // Update lower right
        SetParameterFloat("outputs.lrx", GetParameterFloat("outputs.ulx") + GetParameterFloat("outputs.spacingx") * static_cast<double>(GetParameterInt("outputs.sizex")));
        SetParameterFloat("outputs.lry", GetParameterFloat("outputs.uly") + GetParameterFloat("outputs.spacingy") * static_cast<double>(GetParameterInt("outputs.sizey")));
        }
        break;
        case Mode_AutomaticSpacing:
        {
        // Disable the spacing fields and enable the size fields
        DisableParameter("outputs.ulx");
        DisableParameter("outputs.uly");
        DisableParameter("outputs.spacingx");
        DisableParameter("outputs.spacingy");
        EnableParameter("outputs.sizex");
        EnableParameter("outputs.sizey");
        DisableParameter("outputs.lrx");
        DisableParameter("outputs.lry");
        DisableParameter("outputs.ortho");

        // Update the automatic value mode of each filed
        AutomaticValueOn("outputs.ulx");
        AutomaticValueOn("outputs.uly");
        AutomaticValueOn("outputs.spacingx");
        AutomaticValueOn("outputs.spacingy");
        AutomaticValueOff("outputs.sizex");
        AutomaticValueOff("outputs.sizey");
        AutomaticValueOn("outputs.lrx");
        AutomaticValueOn("outputs.lry");

        // Adapat the status of the param to this mode
        MandatoryOff("outputs.ulx");
        MandatoryOff("outputs.uly");
        MandatoryOff("outputs.spacingx");
        MandatoryOff("outputs.spacingy");
        MandatoryOn("outputs.sizex");
        MandatoryOn("outputs.sizey");
        MandatoryOff("outputs.lrx");
        MandatoryOff("outputs.lry");
        MandatoryOff("outputs.ortho");

        ResampleFilterType::SizeType size;
        size[0] = GetParameterInt("outputs.sizex");
        size[1] = GetParameterInt("outputs.sizey");

        genericRSEstimator->ForceSizeTo(size);
        genericRSEstimator->Compute();

        // Set the  processed spacing relative to this forced size
        SetParameterFloat("outputs.spacingx", genericRSEstimator->GetOutputSpacing()[0]);
        SetParameterFloat("outputs.spacingy", genericRSEstimator->GetOutputSpacing()[1]);

        // Reset Origin to default
        SetParameterFloat("outputs.ulx", genericRSEstimator->GetOutputOrigin()[0]);
        SetParameterFloat("outputs.uly", genericRSEstimator->GetOutputOrigin()[1]);

        // Update lower right
        SetParameterFloat("outputs.lrx", GetParameterFloat("outputs.ulx") + GetParameterFloat("outputs.spacingx") * static_cast<double>(GetParameterInt("outputs.sizex")));
        SetParameterFloat("outputs.lry", GetParameterFloat("outputs.uly") + GetParameterFloat("outputs.spacingy") * static_cast<double>(GetParameterInt("outputs.sizey")));

        }
        break;
        case Mode_OutputROI:
        {
          // Set the size according to the output ROI
          EnableParameter("outputs.ulx");
          EnableParameter("outputs.uly");
          DisableParameter("outputs.sizex");
          DisableParameter("outputs.sizey");
          EnableParameter("outputs.spacingx");
          EnableParameter("outputs.spacingy");
          EnableParameter("outputs.lrx");
          EnableParameter("outputs.lry");
          DisableParameter("outputs.ortho");

          // Update the automatic value mode of each filed
          AutomaticValueOff("outputs.ulx");
          AutomaticValueOff("outputs.uly");
          AutomaticValueOn("outputs.sizex");
          AutomaticValueOn("outputs.sizey");
          AutomaticValueOff("outputs.spacingx");
          AutomaticValueOff("outputs.spacingy");
          AutomaticValueOff("outputs.lrx");
          AutomaticValueOff("outputs.lry");

          // Adapt the status of the param to this mode
          MandatoryOn("outputs.ulx");
          MandatoryOn("outputs.uly");
          MandatoryOn("outputs.spacingx");
          MandatoryOn("outputs.spacingy");
          MandatoryOff("outputs.sizex");
          MandatoryOff("outputs.sizey");
          MandatoryOn("outputs.lrx");
          MandatoryOn("outputs.lry");
          MandatoryOff("outputs.ortho");

          ResampleFilterType::SpacingType spacing;
          spacing[0] = GetParameterFloat("outputs.spacingx");
          spacing[1] = GetParameterFloat("outputs.spacingy");

          // Set the  processed size relative to this forced spacing
          if (vcl_abs(spacing[0]) > 0.0)
            SetParameterInt("outputs.sizex", static_cast<int>(vcl_ceil((GetParameterFloat("outputs.lrx")-GetParameterFloat("outputs.ulx"))/spacing[0])));
          if (vcl_abs(spacing[1]) > 0.0)
            SetParameterInt("outputs.sizey", static_cast<int>(vcl_ceil((GetParameterFloat("outputs.lry")-GetParameterFloat("outputs.uly"))/spacing[1])));
        }
        break;
        case Mode_OrthoFit:
        {
          // Make all the parameters in this mode mandatory
          MandatoryOff("outputs.ulx");
          MandatoryOff("outputs.uly");
          MandatoryOff("outputs.spacingx");
          MandatoryOff("outputs.spacingy");
          MandatoryOff("outputs.sizex");
          MandatoryOff("outputs.sizey");
          MandatoryOff("outputs.lrx");
          MandatoryOff("outputs.lry");
          MandatoryOn("outputs.ortho");

          // Disable the parameters
          DisableParameter("outputs.ulx");
          DisableParameter("outputs.uly");
          DisableParameter("outputs.spacingx");
          DisableParameter("outputs.spacingy");
          DisableParameter("outputs.sizex");
          DisableParameter("outputs.sizey");
          DisableParameter("outputs.lrx");
          DisableParameter("outputs.lry");
          EnableParameter("outputs.ortho");

          if (HasValue("outputs.ortho"))
          {
            // Automatic set to on
            AutomaticValueOn("outputs.ulx");
            AutomaticValueOn("outputs.uly");
            AutomaticValueOn("outputs.sizex");
            AutomaticValueOn("outputs.sizey");
            AutomaticValueOn("outputs.spacingx");
            AutomaticValueOn("outputs.spacingy");
            AutomaticValueOn("outputs.lrx");
            AutomaticValueOn("outputs.lry");

            // input image
            FloatVectorImageType::Pointer inOrtho = GetParameterImage("outputs.ortho");

            ResampleFilterType::OriginType orig = inOrtho->GetOrigin();
            ResampleFilterType::SpacingType spacing = inOrtho->GetSpacing();
            ResampleFilterType::SizeType size = inOrtho->GetLargestPossibleRegion().GetSize();

            SetParameterInt("outputs.sizex",size[0]);
            SetParameterInt("outputs.sizey",size[1]);
            SetParameterFloat("outputs.spacingx",spacing[0]);
            SetParameterFloat("outputs.spacingy",spacing[1]);
            SetParameterFloat("outputs.ulx", orig[0]);
            SetParameterFloat("outputs.uly", orig[1]);
            // Update lower right
            SetParameterFloat("outputs.lrx", GetParameterFloat("outputs.ulx") + GetParameterFloat("outputs.spacingx") * static_cast<double>(GetParameterInt("outputs.sizex")));
            SetParameterFloat("outputs.lry", GetParameterFloat("outputs.uly") + GetParameterFloat("outputs.spacingy") * static_cast<double>(GetParameterInt("outputs.sizey")));
          }
        }
        break;
        }
      }
  }

  void DoExecute()
    {
    GetLogger()->Debug("Entering DoExecute\n");

    // Get the input image
    FloatVectorImageType* inImage = GetParameterImage("io.in");

    // Resampler Instanciation
    m_ResampleFilter = ResampleFilterType::New();
    m_ResampleFilter->SetInput(inImage);

    // Set the output projection Ref
    m_ResampleFilter->SetInputProjectionRef(inImage->GetProjectionRef());
    m_ResampleFilter->SetInputKeywordList(inImage->GetImageKeywordlist());
    m_ResampleFilter->SetOutputProjectionRef(m_OutputProjectionRef);

    // Check size
    if (GetParameterInt("outputs.sizex") <= 0 || GetParameterInt("outputs.sizey") <= 0)
      {
      otbAppLogCRITICAL("Wrong value : negative size : ("<<GetParameterInt("outputs.sizex")<<" , "<<GetParameterInt("outputs.sizey")<<")");
      }

    // Get Interpolator
    switch ( GetParameterInt("interpolator") )
      {
      case Interpolator_Linear:
      {
      typedef itk::LinearInterpolateImageFunction<FloatVectorImageType,
        double>          LinearInterpolationType;
      LinearInterpolationType::Pointer interpolator = LinearInterpolationType::New();
      m_ResampleFilter->SetInterpolator(interpolator);
      }
      break;
      case Interpolator_NNeighbor:
      {
      typedef itk::NearestNeighborInterpolateImageFunction<FloatVectorImageType,
        double> NearestNeighborInterpolationType;
      NearestNeighborInterpolationType::Pointer interpolator = NearestNeighborInterpolationType::New();
      m_ResampleFilter->SetInterpolator(interpolator);
      }
      break;
      case Interpolator_BCO:
      {
      typedef otb::BCOInterpolateImageFunction<FloatVectorImageType>     BCOInterpolationType;
      BCOInterpolationType::Pointer interpolator = BCOInterpolationType::New();
      interpolator->SetRadius(GetParameterInt("interpolator.bco.radius"));
      m_ResampleFilter->SetInterpolator(interpolator);
      }
      break;
      }

    // Setup the DEM Handler
    otb::Wrapper::ElevationParametersHandler::SetupDEMHandlerFromElevationParameters(this,"elev");

    // If activated, generate RPC model
    if(IsParameterEnabled("opt.rpc"))
      {
      m_ResampleFilter->EstimateInputRpcModelOn();
      m_ResampleFilter->SetInputRpcGridSize( GetParameterInt("opt.rpc"));
      }

    // Set Output information
    ResampleFilterType::SizeType size;
    size[0] = GetParameterInt("outputs.sizex");
    size[1] = GetParameterInt("outputs.sizey");
    m_ResampleFilter->SetOutputSize(size);

    ResampleFilterType::SpacingType spacing;
    spacing[0] = GetParameterFloat("outputs.spacingx");
    spacing[1] = GetParameterFloat("outputs.spacingy");
    m_ResampleFilter->SetOutputSpacing(spacing);

    ResampleFilterType::OriginType ul;
    ul[0] = GetParameterFloat("outputs.ulx");
    ul[1] = GetParameterFloat("outputs.uly");
    m_ResampleFilter->SetOutputOrigin(ul);

    // Build the default pixel
    FloatVectorImageType::PixelType defaultValue;
    defaultValue.SetSize(inImage->GetNumberOfComponentsPerPixel());
    defaultValue.Fill(GetParameterFloat("outputs.default"));
    m_ResampleFilter->SetEdgePaddingValue(defaultValue);


    // Deformation Field spacing
    ResampleFilterType::SpacingType gridSpacing;
    if (IsParameterEnabled("opt.gridspacing"))
      {
      gridSpacing[0] = GetParameterFloat("opt.gridspacing");
      gridSpacing[1] = -GetParameterFloat("opt.gridspacing");
      m_ResampleFilter->SetDeformationFieldSpacing(gridSpacing);
      }

    // Output Image
    SetParameterOutputImage("io.out", m_ResampleFilter->GetOutput());
    }

  ResampleFilterType::Pointer     m_ResampleFilter;
  std::string                     m_OutputProjectionRef;
  };

  } // namespace Wrapper
} // namespace otb

OTB_APPLICATION_EXPORT(otb::Wrapper::OrthoRectification)