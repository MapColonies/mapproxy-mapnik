DELETE FROM public.ne_10m_admin_0_boundary_lines_land
	WHERE adm0_a3_l in ('AFG', 'ARM','AZE','BHR','BGR','CYP','EGY','ETH','GEO','IRN','IRQ','ISR','JOR','KWT','LBN','OMN','PAK','PSE','QAT','SAU','SOM','SSD','SDN','SYR','TUR','TKM','ARE','UZB','YEM')
	     or adm0_a3_r in('AFG', 'ARM','AZE','BHR','BGR','CYP','EGY','ETH','GEO','IRN','IRQ','ISR','JOR','KWT','LBN','OMN','PAK','PSE','QAT','SAU','SOM','SSD','SDN','SYR','TUR','TKM','ARE','UZB','YEM');
	
DELETE FROM public.ne_10m_populated_places
	WHERE sov_a3 in ('AFG', 'ARM','AZE','BHR','BGR','CYP','EGY','ETH','GEO','IRN','IRQ','ISR','JOR','KWT','LBN','OMN','PAK','PSE','QAT','SAU','SOM','SSD','SDN','SYR','TUR','TKM','ARE','UZB','YEM')
	     or adm0_a3 in('AFG', 'ARM','AZE','BHR','BGR','CYP','EGY','ETH','GEO','IRN','IRQ','ISR','JOR','KWT','LBN','OMN','PAK','PSE','QAT','SAU','SOM','SSD','SDN','SYR','TUR','TKM','ARE','UZB','YEM');

DELETE FROM public.ne_10m_admin_0_countries_isr
	WHERE sov_a3 in ('AFG', 'ARM','AZE','BHR','BGR','CYP','EGY','ETH','GEO','IRN','IRQ','ISR','JOR','KWT','LBN','OMN','PAK','PSE','QAT','SAU','SOM','SSD','SDN','SYR','TUR','TKM','ARE','UZB','YEM')
	     or adm0_a3 in('AFG', 'ARM','AZE','BHR','BGR','CYP','EGY','ETH','GEO','IRN','IRQ','ISR','JOR','KWT','LBN','OMN','PAK','PSE','QAT','SAU','SOM','SSD','SDN','SYR','TUR','TKM','ARE','UZB','YEM');
	
