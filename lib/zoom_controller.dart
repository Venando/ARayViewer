import 'package:flutter/foundation.dart';
import 'constants.dart';

class ZoomController extends ValueNotifier<double> {

  double preferedZoom = -1.0;

  ZoomController(super.value);

  ZoomController.default1() : super(1.0);
  
  double notAppliedZoom = -1.0;
  bool usePreferredZoomAsMin = false;

  void setUsePreferredZoomAsMin(bool value) {
    usePreferredZoomAsMin = value;
  }

  void setZoom(double zoom) {
    value = clampDouble(zoom, minZoom, maxZoom);
  }

  double zoom(double zoomChange, bool applyChanges) {
    
    if (zoomChange == 1.0) {
      return value;
    }

    assert(zoomChange != 0.0);

    final double currentZoom = value;
    
    double newZoom = currentZoom * zoomChange;

    bool isJumpOverPreferedZoom = (currentZoom < preferedZoom && newZoom > preferedZoom) ||
      (currentZoom > preferedZoom && newZoom < preferedZoom);

    //bool isCloseToPreferedZoom = (newZoom != preferedZoom) && ((newZoom - preferedZoom).abs() < 0.001);

    if (isJumpOverPreferedZoom) { // || isCloseToPreferedZoom) {
      // newZoom jumps over preferedZoom, so set to preferedZoom
      newZoom = preferedZoom;
    }
    
    final resultZoom = clampDouble(
      newZoom,
      getMinZoom(),
      maxZoom,
    );

    if (applyChanges) {
      value = resultZoom;
    } else {
      notAppliedZoom = resultZoom;
    }

    return resultZoom;
  }

  void applyZoom() {
    
    if (notAppliedZoom == -1.0) {
      return; // No zoom to apply
    }

    value = notAppliedZoom;
    notAppliedZoom = -1.0;
  }

  void setPreferedZoom(double zoom) {
    preferedZoom = clampDouble(zoom, minZoom, maxZoom);
    value = clampDouble(value, getMinZoom(), maxZoom);
  }

  double getMinZoom() {
    return usePreferredZoomAsMin ? preferedZoom : minZoom;
  }
}
