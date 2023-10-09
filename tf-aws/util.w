bring "cdk8s" as k8s9;

class Util {
  extern "./util.js" pub static toHelmChart(chart: k8s9.Chart): str;
}