# wise-paas-ota-agent-risc-linux
we aims to provide a solution for wise-paas ota agent about risc linux system.<br />
【Requirement】<br />
I take rsb4220(TI am335x based) for example and it runs linux-3.2.0 <br />
【Architecture】<br />
The overall architecture is here:<br />
http://ess-wiki.advantech.com.tw/view/WISE-PaaS/OTA_Agent(risc_linux) <br />
【Directory】<br />
/makeSD:<br />
script for format sd card to meet the requirement of ota under risc linux<br />
/doOTA:<br />
script for ota process, invoked by ota-agent<br />
