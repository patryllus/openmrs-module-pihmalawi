#!/bin/bash

# runs cleanup/maintenance/convenience statements against openmrs db

LOGFILE=$$.log
exec > $LOGFILE 2>&1

PATH=$PATH:/bin:/usr/bin:/home/emradmin/pihmalawi/scripts

source run_report.config

echo "Start cleanup `date`"

mysql -u $MYSQL_USER -p$MYSQL_PW $MYSQL_DB <<EOF

-- clean up old reporting request, they sloooow down opening the reporting tab
delete from reporting_report_request; -- where request_datetime < subdate(now(), interval 1 week);

-- update identifier locations
-- LSI
update patient_identifier set location_id=16 where identifier like 'LSI%' and identifier_type in (4,19);
-- MTE
update patient_identifier set location_id=22 where identifier like 'MTE%' and identifier_type in (4,19);
-- CFGA
update patient_identifier set location_id=18 where identifier like 'CFGA%' and identifier_type in (4,19);
-- ZLA
update patient_identifier set location_id=35 where identifier like 'ZLA%' and identifier_type in (4,19);
-- NKA
update patient_identifier set location_id=21 where identifier like 'NKA%' and identifier_type in (4,19);
-- LWAN
update patient_identifier set location_id=17 where identifier like 'LWAN%' and identifier_type in (4,19);
-- NNO
update patient_identifier set location_id=2 where identifier like 'NNO%' and identifier_type in (4,19);
-- NOP
update patient_identifier set location_id=4 where identifier like 'NOP%' and identifier_type in (4,19);
-- NSM
update patient_identifier set location_id=20 where identifier like 'NSM%' and identifier_type in (4,19);
-- MGT
update patient_identifier set location_id=3 where identifier like 'MGT%' and identifier_type in (4,19);
-- LGWE
update patient_identifier set location_id=34 where identifier like 'LGWE%' and identifier_type in (4,19);
-- MTDN
update patient_identifier set location_id=5 where identifier like 'MTDN%' and identifier_type in (4,19);

-- create health center person attribute if it doesn't exist

-- set health center based on last hiv encounter location
update person_attribute pa
  set value = (select e.location_id from encounter e where pa.person_id=e.patient_id and e.voided=0 and e.encounter_type in (9, 10, 11, 12, 92, 93) order by e.encounter_datetime DESC limit 1)
  where pa.person_attribute_type_id=7 and pa.voided = 0;

-- set ARV number (if exists) or HCC number (if exists) as preferred for current enrollment location
-- 1. clear our all preferred patient identifiers, todo: only do this for HIV patients
update patient_identifier pi
  set pi.preferred=0;
-- 2. set preferred for all ARV and HCC numbers for the location of the last encounter
update patient_identifier pi, person_attribute pa 
  set pi.preferred=1 
  where pi.voided=0 and (pi.identifier_type=19 or pi.identifier_type=4) and pi.patient_id = pa.person_id 
    and pa.voided=0 and pa.person_attribute_type_id=7 and pa.value=pi.location_id;
-- 3. make sure that if a patient has an ARV and HCC number, only the ARV number is taken
update patient_identifier pi
  set preferred=0
  where identifier_type=19 and patient_id in 
    (select * from (
      select patient_id from patient_identifier where preferred=1 and voided=0 group by patient_id, preferred having count(*)>1
    ) as t);

-- remove double addresses and names without any difference

-- breakdown of encounters for BART2

-- BART2 compliant regimens

-- void encounters from voided and deleted patients

-- void obs from voided encounters

-- void obs from voided and deleted patients

-- void/delete persons and patients from voided/deleted patients and persons

-- void addresses, names from deleted and voided persons

-- void relationships if person a or person b was voided
update relationship rs, person p set rs.voided=1 where p.person_id = rs.person_a and p.voided=1 and rs.voided=0;
update relationship rs, person p set rs.voided=1 where p.person_id = rs.person_b and p.voided=1 and rs.voided=0;
EOF

echo "Finish cleanup `date`"

MAIL=apzu-emr@apzu.pih.org
PATH=$PATH:/bin:/usr/bin:/home/emradmin/pihmalawi/scripts
TODAY=`date +%Y%m%d`
mailx -s "emr: OpenMRS SQL cleanup done $TODAY" "$MAIL" < $LOGFILE
rm $LOGFILE

