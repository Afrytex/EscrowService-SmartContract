pragma solidity ^0.4.24;

import './ownable.sol';
import './safemath.sol';

/**
 * @title EscrowService
 * @author Afrytex <afrytex@gmail.com>
 * @dev A simple escrow service smart contract
 */

contract EscrowService is Ownable {

	using SafeMath for uint256;

	/**
	* @dev These constants are used to define the different states an agreement can be in
	*/
	uint8 constant statusPaid = 2;
	uint8 constant statusCreated = 1;
	uint8 constant statusCanceled = 0;

	/**
	* @dev This variable is used to calculate the share of the smart contract from the amount of the agreement
	* for example, if the amount was 100ether and this was set to 10 the contract would take 10% of that amount
	* as commission
	*/
	uint8 public cut = 1;

	/**
	* @dev The mappings below are used to see how many agreements an address is involved in
	*/
	mapping(address => uint256) addressSenderAgreementCount;
	mapping(address => uint256) addressReceiverAgreementCount;
	mapping(address => uint256) addressMiddlemanAgreementCount;

	/**
	* @dev Since the amount of an agreement or the amount of the commission might be too low sometimes it wouldn't
	* be wise to automatically pay them directly to the user so whenever a transaction is going to take place
	* instead of sending the amount directly to the address the contract will use the mapping below to add to
	* the "balance" of the address in the mapping below. Whenever the user wanted to withdraw their funds they can
	* send a request to the balanceWithdraw function and receive their money
	*/
	mapping(address => uint256) public addressBalance;

	struct Agreement {
		address sender; // The person who created the agreement
		address receiver; // The person who will receive a payment if all goes well
		address middleman; // This person is going to be the judge if the sender and receiver don't agree with each other
		uint256 amount; // The amount the receiver is going to get (the smart contract will take its commission from this
		// and it'll take the commission no matter if the agreement was canceled or not)
		uint256 commission; // The amount the middleman will get (it'll be paid to him no matter if the agreement got canceled or got paid)
		uint8 status;
	}
	Agreement[] public Agreements;

	event newAgreement(uint256 agId); // Whenever a new agreement gets added, the contract will trigger this event with the new agreement's ID
	event agUpdated(uint256 agId, uint8 status); // Whenever an agreement's status changes, the contract will trigger this event with the agreement's ID and new status

	/**
	* @dev A function with this modifier will only be executed when the agreement hasn't been changed already and the sender of the request is
	* either the middleman or the sender
	*/
	modifier canPayOnly(uint256 _agId){
		require((msg.sender == Agreements[_agId].sender || msg.sender == Agreements[_agId].middleman) && Agreements[_agId].status == statusCreated);
		_;
	}

	/**
	* @dev A function with this modifier will only be executed when the agreement hasn't been changed already and the sender of the request is
	* either the middleman or the receiver
	*/
	modifier canCancelOnly(uint256 _agId){
		require((msg.sender == Agreements[_agId].receiver || msg.sender == Agreements[_agId].middleman) && Agreements[_agId].status == statusCreated);
		_;
	}


	/**
	* @dev This will create a new agreement and trigger the newAgreement event
	* If the middleman was set to 0x0 (basically no one) the contract will change it to the owner of the contract
	*/
	function createAgreement(address _receiver, address _middleman, uint256 _amount, uint256 _commission) external payable {
		require(msg.value == (_amount.add(_commission)) && msg.sender != _middleman && msg.sender != _receiver && _receiver != _middleman);
		address middleman = _middleman;
		if(middleman == address(0)){
			middleman = owner();
		}
		uint256 newAg = Agreements.push(Agreement(msg.sender, _receiver, middleman, _amount, _commission, statusCreated));
		uint256 contractCut = _amount.div(100).mul(cut);
		addressBalance[address(this)] = addressBalance[address(this)].add(contractCut);
		addressSenderAgreementCount[msg.sender] = addressSenderAgreementCount[msg.sender].add(1);
		addressReceiverAgreementCount[_receiver] = addressReceiverAgreementCount[_receiver].add(1);
		addressMiddlemanAgreementCount[middleman] = addressMiddlemanAgreementCount[middleman].add(1);
		emit newAgreement(newAg);
	}

	/**
	* @dev The three functions below are used to get the state of a certain agreement based on it's ID
	*/
	function isPaid(uint256 _agId) public view returns(bool) {
		return (Agreements[_agId].status == statusPaid);
	}

	function isCanceled(uint256 _agId) public view returns(bool) {
		return (Agreements[_agId].status == statusCanceled);
	}

	function isUnchanged(uint256 _agId) public view returns(bool) {
		return (Agreements[_agId].status == statusCreated);
	}

	/**
	* @dev This function is used to see what an address has to do with an agreement
	* 1 -> Sender
	* 2 -> Receiver
	* 3 -> Middleman
	* 0 -> Nothing
	*/
	function roleInAgreement(uint256 _agId, address _addr) public view returns(uint8){
		if(Agreements[_agId].sender == _addr){
			return uint8(1);
		}else if(Agreements[_agId].receiver == _addr){
			return uint8(2);
		}else if(Agreements[_agId].middleman == _addr){
			return uint8(3);
		}else{
			return uint8(0);
		}
	}

	/**
	* @dev The three functions below are used to get the agreements an address is involved in
	*/
	function getAgreementsSender(address _addr) public view returns(uint256[]){
		uint256 len=Agreements.length;
		uint256[] memory _addrAgreements = new uint256[](addressSenderAgreementCount[_addr]);
		uint256 c=0;
		for(uint256 i=0;i<len;i++){
			if(Agreements[i].sender == _addr){
				_addrAgreements[c++] = i;
			}
		}
		return _addrAgreements;
	}
	function getAgreementsReceiver(address _addr) public view returns(uint256[]){
		uint256 len=Agreements.length;
		uint256[] memory _addrAgreements = new uint256[](addressReceiverAgreementCount[_addr]);
		uint256 c=0;
		for(uint256 i=0;i<len;i++){
			if(Agreements[i].receiver == _addr){
				_addrAgreements[c++] = i;
			}
		}
		return _addrAgreements;
	}
	function getAgreementsMiddleman(address _addr) public view returns(uint256[]){
		uint256 len=Agreements.length;
		uint256[] memory _addrAgreements = new uint256[](addressMiddlemanAgreementCount[_addr]);
		uint256 c=0;
		for(uint256 i=0;i<len;i++){
			if(Agreements[i].middleman == _addr){
				_addrAgreements[c++] = i;
			}
		}
		return _addrAgreements;
	}

	/**
	* @dev The two functions below are used to cancel or pay an agreement only the receiver & the middleman can cancel an agreement
	* and only the sender & the middleman can pay an agreement
	*/
	function payAgreement(uint256 _agId) external canPayOnly(_agId) {
		Agreements[_agId].status = statusPaid;
		uint256 paymentAmount = Agreements[_agId].amount.sub(Agreements[_agId].amount.div(100).mul(cut));
		addressBalance[Agreements[_agId].receiver] = addressBalance[Agreements[_agId].receiver].add(paymentAmount);
		addressBalance[Agreements[_agId].middleman] = addressBalance[Agreements[_agId].middleman].add(Agreements[_agId].commission);
		emit agUpdated(_agId, statusPaid);
	}
	function cancelAgreement(uint256 _agId) external canCancelOnly(_agId) {
		Agreements[_agId].status = statusCanceled;
		uint256 paymentAmount = Agreements[_agId].amount.sub(Agreements[_agId].amount.div(100).mul(cut));
		addressBalance[Agreements[_agId].sender] = addressBalance[Agreements[_agId].sender].add(paymentAmount);
		addressBalance[Agreements[_agId].middleman] = addressBalance[Agreements[_agId].middleman].add(Agreements[_agId].commission);
		emit agUpdated(_agId, statusCanceled);
	}

	/**
	* @dev This function is used to withdraw money from the contract by the users
	*/
	function balanceWithdraw() external{
		require(addressBalance[msg.sender] > 0);
		uint256 amount = addressBalance[msg.sender];
		addressBalance[msg.sender] = 0;
		msg.sender.transfer(amount);
	}

	/**
	* @dev This function will be used by the contract's owner to withdraw the shares of the contract from an agreement
	*/
	function contractWithdraw() external onlyOwner {
		require(addressBalance[address(this)] > 0);
		uint256 amount = addressBalance[address(this)];
		addressBalance[address(this)] = 0;
		msg.sender.transfer(amount);
	}

	/**
	* @dev This function will be used by the contract's owner to change the cut the contract takes from an agreement's amount
	*/
	function contractChangeCut(uint8 _newCut) external onlyOwner {
		cut = _newCut;
	}
}