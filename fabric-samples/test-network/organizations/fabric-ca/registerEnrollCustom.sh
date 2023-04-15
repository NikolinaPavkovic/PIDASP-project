function createOrg() {
    ORG="$1"
    PORT=$2

    echo "$1"
    echo "OVAKO: $ORG"
    infoln "Enroll the CA admin"
    mkdir -p organizations/peerOrganizations/${1}.example.com/

    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/${1}.example.com/

    set -x
    fabric-ca-client enroll -u https://admin:adminpw@localhost:${2} --caname ca-${1} --tls.certfiles ${PWD}/organizations/fabric-ca/${1}/tls-cert.pem
    { set +x; } 2>/dev/null

    echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
        Certificate: cacerts/localhost-${2}-ca-${1}.pem
        OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
        Certificate: cacerts/localhost-${2}-ca-${1}.pem
        OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
        Certificate: cacerts/localhost-${2}-ca-${1}.pem
        OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
        Certificate: cacerts/localhost-${2}-ca-${1}.pem
        OrganizationalUnitIdentifier: orderer" >${PWD}/organizations/peerOrganizations/${1}.example.com/msp/config.yaml

    local counter=0
    local peer_num=4
    while [ $counter -lt $peer_num ]
    do
        infoln "Registering peer${counter}"
        set -x
        fabric-ca-client register --caname ca-${1} --id.name peer${counter} --id.secret peer${counter}pw --id.type peer --tls.certfiles ${PWD}/organizations/fabric-ca/${1}/tls-cert.pem
        { set +x; } 2>/dev/null
        counter=$(($counter + 1))
    done

    infoln "Registering user"
    set -x
    fabric-ca-client register --caname ca-${1} --id.name user1 --id.secret user1pw --id.type client --tls.certfiles ${PWD}/organizations/fabric-ca/${1}/tls-cert.pem
    { set +x; } 2>/dev/null

    infoln "Registering the org admin"
    set -x
    fabric-ca-client register --caname ca-${1} --id.name ${1}admin --id.secret ${1}adminpw --id.type admin --tls.certfiles ${PWD}/organizations/fabric-ca/${1}/tls-cert.pem
    { set +x; } 2>/dev/null


    local counter=0
    while [ $counter -lt $peer_num ]
    do
        infoln "Generating the peer${counter} msp"
        set -x
        fabric-ca-client enroll -u https://peer${counter}:peer${counter}pw@localhost:${2} --caname ca-${1} -M ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/msp --csr.hosts peer${counter}.${1}.example.com --tls.certfiles ${PWD}/organizations/fabric-ca/${1}/tls-cert.pem
        { set +x; } 2>/dev/null

        cp ${PWD}/organizations/peerOrganizations/${1}.example.com/msp/config.yaml ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/msp/config.yaml

        infoln "Generating the peer${counter}-tls certificates"
        set -x
        fabric-ca-client enroll -u https://peer${counter}:peer${counter}pw@localhost:${2} --caname ca-${1} -M ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/tls --enrollment.profile tls --csr.hosts peer${counter}.${1}.example.com --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/${1}/tls-cert.pem
        { set +x; } 2>/dev/null

        cp ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/tls/ca.crt
        cp ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/tls/signcerts/* ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/tls/server.crt
        cp ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/tls/keystore/* ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/tls/server.key

        mkdir -p ${PWD}/organizations/peerOrganizations/${1}.example.com/msp/tlscacerts
        cp ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${1}.example.com/msp/tlscacerts/ca.crt

        mkdir -p ${PWD}/organizations/peerOrganizations/${1}.example.com/tlsca
        cp ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/tls/tlscacerts/* ${PWD}/organizations/peerOrganizations/${1}.example.com/tlsca/tlsca.${1}.example.com-cert.pem

        mkdir -p ${PWD}/organizations/peerOrganizations/${1}.example.com/ca
        cp ${PWD}/organizations/peerOrganizations/${1}.example.com/peers/peer${counter}.${1}.example.com/msp/cacerts/* ${PWD}/organizations/peerOrganizations/${1}.example.com/ca/ca.${1}.example.com-cert.pem

        counter=$(($counter + 1))
    done



    infoln "Generating the user msp"
    set -x
    fabric-ca-client enroll -u https://user1:user1pw@localhost:${2} --caname ca-${1} -M ${PWD}/organizations/peerOrganizations/${1}.example.com/users/User1@${1}.example.com/msp --tls.certfiles ${PWD}/organizations/fabric-ca/${1}/tls-cert.pem
    { set +x; } 2>/dev/null

    cp ${PWD}/organizations/peerOrganizations/${1}.example.com/msp/config.yaml ${PWD}/organizations/peerOrganizations/${1}.example.com/users/User1@${1}.example.com/msp/config.yaml

    infoln "Generating the org admin msp"
    set -x
    fabric-ca-client enroll -u https://${1}admin:${1}adminpw@localhost:${2} --caname ca-${1} -M ${PWD}/organizations/peerOrganizations/${1}.example.com/users/Admin@${1}.example.com/msp --tls.certfiles ${PWD}/organizations/fabric-ca/${1}/tls-cert.pem
    { set +x; } 2>/dev/null

    cp ${PWD}/organizations/peerOrganizations/${1}.example.com/msp/config.yaml ${PWD}/organizations/peerOrganizations/${1}.example.com/users/Admin@${1}.example.com/msp/config.yaml


}


function createOrderer() {
    infoln "Enrolling the CA admin"
    mkdir -p organizations/ordererOrganizations/example.com

    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations/example.com

    set -x
    fabric-ca-client enroll -u https://admin:adminpw@localhost:9054 --caname ca-orderer --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem
    { set +x; } 2>/dev/null

    echo 'NodeOUs:
    Enable: true
    ClientOUIdentifier:
        Certificate: cacerts/localhost-9054-ca-orderer.pem
        OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
        Certificate: cacerts/localhost-9054-ca-orderer.pem
        OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
        Certificate: cacerts/localhost-9054-ca-orderer.pem
        OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
        Certificate: cacerts/localhost-9054-ca-orderer.pem
        OrganizationalUnitIdentifier: orderer' >${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml

    infoln "Registering orderer"
    set -x
    fabric-ca-client register --caname ca-orderer --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem
    { set +x; } 2>/dev/null

    infoln "Registering the orderer admin"
    set -x
    fabric-ca-client register --caname ca-orderer --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem
    { set +x; } 2>/dev/null

    infoln "Generating the orderer msp"
    set -x
    fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem
    { set +x; } 2>/dev/null

    cp ${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/config.yaml

    infoln "Generating the orderer-tls certificates"
    set -x
    fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls --enrollment.profile tls --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem
    { set +x; } 2>/dev/null

    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/signcerts/* ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/keystore/* ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

    mkdir -p ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts
    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

    mkdir -p ${PWD}/organizations/ordererOrganizations/example.com/msp/tlscacerts
    cp ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/tlscacerts/* ${PWD}/organizations/ordererOrganizations/example.com/msp/tlscacerts/tlsca.example.com-cert.pem

    infoln "Generating the admin msp"
    set -x
    fabric-ca-client enroll -u https://ordererAdmin:ordererAdminpw@localhost:9054 --caname ca-orderer -M ${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp --tls.certfiles ${PWD}/organizations/fabric-ca/ordererOrg/tls-cert.pem
    { set +x; } 2>/dev/null

    cp ${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml ${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp/config.yaml
}
