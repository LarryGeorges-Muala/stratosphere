FROM ubuntu:24.04

## REPORTS | SETUP
RUN rm -rf /.vulnerabilities || true
RUN mkdir /.vulnerabilities


## TRIVY | SETUP
RUN apt update && apt install -y gnupg curl wget unzip ca-certificates git
RUN wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | tee -a /etc/apt/sources.list.d/trivy.list
RUN apt-get update
RUN apt-get install trivy -y


## SBOM - Syft/Grype | SETUP
RUN curl -sSfL https://get.anchore.io/syft | sh -s -- -b /usr/local/bin
RUN curl -sSfL https://get.anchore.io/grype | sh -s -- -b /usr/local/bin


## SAST / Semgrep | SETUP
RUN apt install python3 -y
RUN apt install python3-pip -y
RUN apt install python3-venv -y
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN python3 -m pip install semgrep
RUN mkdir -p $HOME/custom-semgrep-rules
ENV SEMGREP_SEND_METRICS=off
RUN python3 -m pip install semgrep-rules-manager

RUN semgrep-rules-manager --dir $HOME/custom-semgrep-rules download
RUN ls $HOME/custom-semgrep-rules

## MANUAL SCANNING: docker exec -it vulnerabilities /bin/sh

## TRIVY
# RUN trivy fs /app >> /.vulnerabilities/trivy.log


## SBOM - Syft/Grype
# RUN syft /app -o cyclonedx-json=/.vulnerabilities/sbom.json
# RUN grype sbom:/.vulnerabilities/sbom.json >> /.vulnerabilities/grype.log


# ### SAST / Semgrep / hashicorp
# RUN python3 -m venv ./.venv
# RUN . ./.venv/bin/activate
# RUN python3 -m pip install semgrep
# RUN cd /app
# RUN semgrep --config="$HOME/custom-semgrep-rules/hashicorp" --metrics=off --dataflow-traces --debug >> /.vulnerabilities/semgrep.hashicorp.log
# ### SAST / Semgrep / 0xdea
# RUN semgrep --config="$HOME/custom-semgrep-rules/0xdea" --metrics=off --dataflow-traces --debug >> /.vulnerabilities/semgrep.0xdea.log
# ### SAST / Semgrep / akabe1
# RUN semgrep --config="$HOME/custom-semgrep-rules/akabe1" --metrics=off --dataflow-traces --debug >> /.vulnerabilities/semgrep.akabe1.log
# ### SAST / Semgrep / atlassian-labs
# RUN semgrep --config="$HOME/custom-semgrep-rules/atlassian-labs" --metrics=off --dataflow-traces --debug >> /.vulnerabilities/semgrep.atlassian-labs.log
# ### SAST / Semgrep / community
# RUN semgrep --config="$HOME/custom-semgrep-rules/community" --metrics=off --dataflow-traces --debug >> /.vulnerabilities/semgrep.community.log
# ### SAST / Semgrep / decurity
# RUN semgrep --config="$HOME/custom-semgrep-rules/decurity" --metrics=off --dataflow-traces >> /.vulnerabilities/semgrep.decurity.log
# ### SAST / Semgrep / dgryski
# RUN semgrep --config="$HOME/custom-semgrep-rules/dgryski" --metrics=off --dataflow-traces --debug >> /.vulnerabilities/semgrep.dgryski.log
# ### SAST / Semgrep / dotta
# RUN semgrep --config="$HOME/custom-semgrep-rules/dotta" --metrics=off --dataflow-traces --debug >> /.vulnerabilities/semgrep.dotta.log
# ### SAST / Semgrep / elttam
# RUN semgrep --config="$HOME/custom-semgrep-rules/elttam" --metrics=off --dataflow-traces --debug >> /.vulnerabilities/semgrep.elttam.log
# ### SAST / Semgrep / kondukto
# RUN semgrep --config="$HOME/custom-semgrep-rules/kondukto" --metrics=off --dataflow-traces --debug >> /.vulnerabilities/semgrep.kondukto.log
# ### SAST / Semgrep / trailofbits
# RUN semgrep --config="$HOME/custom-semgrep-rules/trailofbits" --metrics=off --dataflow-traces --debug >> /.vulnerabilities/semgrep.trailofbits.log


ENTRYPOINT ["/bin/sh", "-c", "while true; do sleep 1; done"]
