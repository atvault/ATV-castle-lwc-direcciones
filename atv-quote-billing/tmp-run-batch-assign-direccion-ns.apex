// Tras desplegar ATV_AssignDireccionAccountByNSBatch: encola el job (lotes de 50).
Id jobId = Database.executeBatch(new ATV_AssignDireccionAccountByNSBatch(), 50);
System.debug('NS_ASSIGN_BATCH|jobId=' + jobId);
