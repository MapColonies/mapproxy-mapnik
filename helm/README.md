# mapproxy-mapnik helm chart
This chart is used to deploy the server on k8s/openshift.
Before deploying, make sure to have a database already populated with the required data, and accessible from the cluster.

Its recommended you create your own values file and not change the values in the default file.

All the options are listed inside the `values.yaml` file, but the main ones that are the `cloudProvider`, `dbConfig` and `route` options.