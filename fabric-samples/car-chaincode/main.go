package main

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct {
	contractapi.Contract
}

type Glitch struct {
	Description string
	RepairPrice float32
}

type CarAsset struct {
	Id         string
	Brand      string
	Model      string
	Year       int32
	Color      string
	OwnerId    string
	Price      float32
	GlitchList []Glitch
}

type PersonAsset struct {
	Id        string
	Firstname string
	Lastname  string
	Email     string
	Cash      float32
}

func main() {

}

func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {

	carAssets := []CarAsset{
		{Id: "asset1", Brand: "Audi", Model: "A6", Year: 2020, Color: "black", OwnerId: "person1", Price: 20000, GlitchList: []Glitch{
			{Description: "Warning lights", RepairPrice: 100},
			{Description: "A sputtering engine", RepairPrice: 1000},
		}},
		{Id: "asset2", Brand: "Renault", Model: "Clio", Year: 2015, Color: "red", OwnerId: "person2", Price: 5000, GlitchList: []Glitch{
			{Description: "Dead battery", RepairPrice: 150},
		}},
		{Id: "asset3", Brand: "Mercedes", Model: "S350", Year: 2022, Color: "white", OwnerId: "person3", Price: 50000, GlitchList: []Glitch{}},
		{Id: "asset4", Brand: "Hyundai", Model: "Tucson", Year: 2021, Color: "grey", OwnerId: "person1", Price: 25000, GlitchList: []Glitch{}},
		{Id: "asset5", Brand: "Opel", Model: "Corsa", Year: 2005, Color: "red", OwnerId: "person2", Price: 4000, GlitchList: []Glitch{
			{Description: "Brakes squeaking", RepairPrice: 500},
			{Description: "Alternator failure", RepairPrice: 700},
			{Description: "Steering Wheel Shaking", RepairPrice: 200},
			{Description: "Overheating", RepairPrice: 500},
		}},
		{Id: "asset6", Brand: "Suzuki", Model: "Swift", Year: 2010, Color: "green", OwnerId: "person2", Price: 5000, GlitchList: []Glitch{
			{Description: "Flat tyres", RepairPrice: 200},
			{Description: "Electrical problem: speakers", RepairPrice: 100},
		}},
	}

	personAssets := []PersonAsset{
		{Id: "person1", Firstname: "Nikolina", Lastname: "Pavkovic", Email: "pavkovicn@hotmail.com", Cash: 5000.0},
		{Id: "person2", Firstname: "Marija", Lastname: "Petrovic", Email: "petrovicma@gmail.com", Cash: 70000.0},
		{Id: "person3", Firstname: "Sara", Lastname: "Poparic", Email: "sarapoparic@gmail.com", Cash: 90000.0},
	}

	for _, carAsset := range carAssets {
		carAssetJSON, err := json.Marshal(carAsset)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(carAsset.Id, carAssetJSON)
		if err != nil {
			return fmt.Errorf("Failed to put to world state. %v", err)
		}
	}

	for _, personAsset := range personAssets {
		personAssetJSON, err := json.Marshal(personAsset)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(personAsset.Id, personAssetJSON)
		if err != nil {
			return fmt.Errorf("Failed to put to world state. %v", err)
		}
	}

	return nil
}

func (s *SmartContract) GetCarAsset(ctx contractapi.TransactionContextInterface, id string) (*CarAsset, error) {
	carAssetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("Failed to read car from world state: %v", err)
	}
	if carAssetJSON == nil {
		return nil, fmt.Errorf("Car asset %s doesn't exist", id)
	}
	var carAsset CarAsset
	err = json.Unmarshal(carAssetJSON, &carAsset)
	if err != nil {
		return nil, err
	}

	return &carAsset, nil
}

func (s *SmartContract) GetPersonAsset(ctx contractapi.TransactionContextInterface, id string) (*PersonAsset, error) {
	personAssetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("Failed to read person from world state: %v", err)
	}
	if personAssetJSON == nil {
		return nil, fmt.Errorf("Person asset %s does not exist.", id)
	}

	var personAsset PersonAsset
	err = json.Unmarshal(personAssetJSON, &personAsset)
	if err != nil {
		return nil, err
	}

	return &personAsset, nil
}

func (s *SmartContract) ChangeCarAsserOwner(ctx contractapi.TransactionContextInterface, id string, newOwnerId string, acceptGlitch bool) (bool, error) {
	carAsset, err := s.GetCarAsset(ctx, id)
	if err != nil {
		return false, err
	}

	if carAsset.OwnerId == newOwnerId {
		return false, fmt.Errorf("Person %s is already the owner of the car.", newOwnerId)
	}

	newOwner, err := s.GetPersonAsset(ctx, newOwnerId)
	if err != nil {
		return false, err
	}

	oldOwner, err := s.GetPersonAsset(ctx, carAsset.OwnerId)
	if err != nil {
		return false, err
	}

	carAssetPrice := float32(0)

	if carAsset.GlitchList == nil || len(carAsset.GlitchList) == 0 {
		carAssetPrice = carAsset.Price
	} else if acceptGlitch {
		glitchPrice := float32(0)
		for _, glitch := range carAsset.GlitchList {
			glitchPrice += glitch.RepairPrice
		}
		carAssetPrice = carAsset.Price - glitchPrice
	} else {
		return false, fmt.Errorf("Glitches are not accepted.")
	}

	carAsset.OwnerId = newOwnerId

	if newOwner.Cash >= carAssetPrice {
		newOwner.Cash -= carAssetPrice
		oldOwner.Cash += carAssetPrice
	}

	carAssetJSON, err := json.Marshal(carAsset)
	if err != nil {
		return false, err
	}

	newOwnerJSON, err := json.Marshal(newOwner)
	if err != nil {
		return false, err
	}

	oldOwnerJSON, err := json.Marshal(oldOwner)
	if err != nil {
		return false, err
	}

	err = ctx.GetStub().PutState(id, carAssetJSON)
	if err != nil {
		return false, err
	}

	err = ctx.GetStub().PutState(newOwner.Id, newOwnerJSON)
	if err != nil {
		return false, err
	}

	err = ctx.GetStub().PutState(oldOwner.Id, oldOwnerJSON)
	if err != nil {
		return false, err
	}

	return true, nil
}

func (s *SmartContract) ChangeCarAssetColor(ctx contractapi.TransactionContextInterface, id string, newColor string) (string, error) {
	carAsset, err := s.GetCarAsset(ctx, id)
	if err != nil {
		return "", err
	}

	carAsset.Color = newColor

	carAssetJSON, err := json.Marshal(carAsset)
	if err != nil {
		return "", err
	}

	err = ctx.GetStub().PutState(id, carAssetJSON)
	if err != nil {
		return "", err
	}

	return newColor, nil

}

func (s *SmartContract) AddGlitchToCarAsset(ctx contractapi.TransactionContextInterface, id string, description string, repairPrice float32) error {
	carAsset, err := s.GetCarAsset(ctx, id)
	if err != nil {
		return err
	}

	newGlitch := Glitch{
		Description: description,
		RepairPrice: repairPrice,
	}

	carAsset.GlitchList = append(carAsset.GlitchList, newGlitch)

	totalRepairPrice := float32(0)
	for _, glitch := range carAsset.GlitchList {
		totalRepairPrice += glitch.RepairPrice
	}

	if totalRepairPrice > carAsset.Price {
		return ctx.GetStub().DelState(id)
	}

	carAssetJSON, err := json.Marshal(carAsset)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(id, carAssetJSON)
	if err != nil {
		return err
	}

	return nil

}

func (s *SmartContract) RepairCarAsset(ctx contractapi.TransactionContextInterface, id string) error {
	carAsset, err := s.GetCarAsset(ctx, id)
	if err != nil {
		return err
	}

	personAsset, err := s.GetPersonAsset(ctx, carAsset.OwnerId)
	if err != nil {
		return err
	}

	totalRepairPrice := float32(0)
	for _, glitch := range carAsset.GlitchList {
		totalRepairPrice += glitch.RepairPrice
		if totalRepairPrice > personAsset.Cash {
			return fmt.Errorf("Owner cannot afford to pay the car repair price.")
		}
	}

	carAsset.GlitchList = []Glitch{}
	personAsset.Cash -= totalRepairPrice

	carAssetJSON, err := json.Marshal(carAsset)
	if err != nil {
		return err
	}

	personAssetJSON, err := json.Marshal(personAsset)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(id, carAssetJSON)
	if err != nil {
		return err
	}

	err = ctx.GetStub().PutState(personAsset.Id, personAssetJSON)
	if err != nil {
		return err
	}

	return nil
}
