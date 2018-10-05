# Escrow Service

## A simple escrow service smart contract

### Features
  - Agreement sides
    - The sender: Creates the agreement (must set the receiver, middleman, amount and commission). *Can only pay the agreement
    - The receiver: Will receive the amount of money in an agreement when the agreement gets paid. *Can only cancel the agreement 
    - The middleman: Is able to cancel and pay an agreement. If one side tries to scam the other side he'll be the judge. He'll receive the commission that was set by the sender when he created the contract no matter if the agreement gets canceled or paid. *If no middleman gets selected the contract will set the owner of the contract as the middle man


  - Contract cut
     - The contract is able to take a percentage of the amount of the agreement for itself as a fee. *The owner will be able to set and change the percentage (The contract will take it's commission from an agreement right when the agreement gets created).

 - Manual payment requests
 	- Automatically paying the different sides of an agreement whether the agreement gets paid or canceled would not be wise because of different reasons (ex: the person who is sending the request to the contract to make the agreement paid/canceled will have to pay the gas price of all the transactions) so whenever an agreement gets paid or gets canceled the funds that were going to get transferred will remain inside the contract and the contract will keep track of how much someone has inside it. Users will be able to withdraw their funds from the contract whenever they want to. *The owner of the contract will only be able to withdraw the funds that are related to his address (ex: commission fees earned as the middleman) and the cuts the contract took from each agreement.

## Contact
If you wanted to contact me for any reasons (ex: Found a bug in the source code) you can send an email to afrytex@gmail.com